#!/usr/bin/env python3
import csv
import random
import re
import subprocess
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent

CODE_BASE_DIR = BASE_DIR / "code_base"
LLM_CODE_DIR = BASE_DIR / "llm_code"
RESULTS_DIR = BASE_DIR / "results"
WORK_DIR = RESULTS_DIR / "work"
RESULTS_CSV = RESULTS_DIR / "results.csv"

BACKENDS = ["tigress"]

TRANSFORMS = [
    "EncodeArithmetic",
    "EncodeLiterals",
    "Flatten",
    "Split",
    "Virtualize",
]

CATEGORIES = [
    "arithmetic",
    "function_call",
    "loops",
]

SAMPLE_COUNT = 20


def run(cmd, timeout=20):
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )


def clean_code(text):
    text = text.strip()

    if text.startswith("```"):
        lines = text.splitlines()

        if lines:
            lines = lines[1:]

        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]

        text = "\n".join(lines).strip()

    if text.startswith("c\n"):
        text = text[2:].strip()

    return text


def detect_function_signature(code):
    pattern = re.compile(
        r'^[ \t]*(int|long|short|char|void|unsigned\s+int|signed\s+int)[ \t\*]+'
        r'([a-zA-Z_][a-zA-Z0-9_]*)[ \t]*\(([^)]*)\)',
        re.MULTILINE
    )

    for match in pattern.finditer(code):
        ret_type = match.group(1).strip()
        func_name = match.group(2).strip()
        params = match.group(3).strip()

        if func_name == "main":
            continue

        signature = match.group(0).strip()
        return ret_type, func_name, params, signature

    return None, None, None, None


def parse_int_params(params):
    params = params.strip()

    if params == "" or params == "void":
        return []

    result = []

    for p in params.split(","):
        p = p.strip()

        if "*" in p:
            return None

        if re.search(r'\bint\b', p):
            result.append(p)
        else:
            return None

    return result


def make_tests(nparams):
    fixed_values = [
        -1000, -100, -42, -10, -3, -2, -1,
        0,
        1, 2, 3, 10, 42, 100, 1000
    ]

    tests = []

    if nparams == 0:
        return [()]

    random.seed(123456)

    for _ in range(100):
        tests.append(tuple(random.choice(fixed_values) for _ in range(nparams)))

    for _ in range(500):
        tests.append(tuple(random.randint(-1000, 1000) for _ in range(nparams)))

    seen = set()
    unique = []

    for t in tests:
        if t not in seen:
            seen.add(t)
            unique.append(t)

    return unique


def generate_harness(original_code, llm_code, func_name, params, tests):
    nparams = len(params)

    test_rows = []

    for t in tests:
        if nparams == 0:
            test_rows.append("{0}")
        else:
            test_rows.append("{" + ", ".join(str(x) for x in t) + "}")

    tests_c = ",\n        ".join(test_rows)

    if nparams == 0:
        array_decl = "int tests[][1]"
        call_original = f"original_{func_name}()"
        call_llm = f"llm_{func_name}()"
    else:
        array_decl = f"int tests[][{nparams}]"
        args = ", ".join(f"tests[i][{i}]" for i in range(nparams))
        call_original = f"original_{func_name}({args})"
        call_llm = f"llm_{func_name}({args})"

    harness = f"""
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <limits.h>

#define main original_main
#define {func_name} original_{func_name}
{original_code}
#undef {func_name}
#undef main

#define main llm_main
#define {func_name} llm_{func_name}
{llm_code}
#undef {func_name}
#undef main

int main(void) {{
    {array_decl} = {{
        {tests_c}
    }};

    int total = sizeof(tests) / sizeof(tests[0]);
    int passed = 0;

    for (int i = 0; i < total; i++) {{
        int a = {call_original};
        int b = {call_llm};

        if (a == b) {{
            passed++;
        }} else {{
            printf("FAIL test=%d original=%d llm=%d\\n", i, a, b);
        }}
    }}

    printf("PASSED=%d TOTAL=%d\\n", passed, total);
    return 0;
}}
"""
    return harness


def count_simple_complexity(code):
    return {
        "lines": len([line for line in code.splitlines() if line.strip()]),
        "if": len(re.findall(r'\bif\b', code)),
        "for": len(re.findall(r'\bfor\b', code)),
        "while": len(re.findall(r'\bwhile\b', code)),
        "switch": len(re.findall(r'\bswitch\b', code)),
        "return": len(re.findall(r'\breturn\b', code)),
        "operators": sum(code.count(op) for op in [
            "+", "-", "*", "/", "%", "^", "&", "|", "<<", ">>"
        ]),
    }


def structural_score(original_code, llm_code):
    a = count_simple_complexity(original_code)
    b = count_simple_complexity(llm_code)

    scores = []

    for key in a:
        x = a[key]
        y = b[key]

        if x == 0 and y == 0:
            scores.append(1.0)
        else:
            scores.append(max(0.0, 1.0 - abs(x - y) / max(x, y, 1)))

    return sum(scores) / len(scores)


def evaluate_sample(backend, transform, category, sample_name):
    original_path = CODE_BASE_DIR / category / f"{sample_name}.c"
    llm_path = LLM_CODE_DIR / backend / transform / category / f"{sample_name}.c"

    sample_work_dir = WORK_DIR / backend / transform / category / sample_name
    sample_work_dir.mkdir(parents=True, exist_ok=True)

    if not original_path.exists():
        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 0,
            "semantic_score": 0.0,
            "structural_score": 0.0,
            "passed": 0,
            "total": 0,
            "status": "missing_original",
        }

    if not llm_path.exists():
        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 0,
            "semantic_score": 0.0,
            "structural_score": 0.0,
            "passed": 0,
            "total": 0,
            "status": "missing_llm_code",
        }

    original_code = original_path.read_text(errors="ignore")
    llm_code = clean_code(llm_path.read_text(errors="ignore"))

    llm_path.write_text(llm_code)

    ret_type, func_name, params, signature = detect_function_signature(original_code)

    if not func_name:
        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 0,
            "semantic_score": 0.0,
            "structural_score": structural_score(original_code, llm_code),
            "passed": 0,
            "total": 0,
            "status": "function_not_detected",
        }

    if ret_type != "int":
        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 0,
            "semantic_score": 0.0,
            "structural_score": structural_score(original_code, llm_code),
            "passed": 0,
            "total": 0,
            "status": "unsupported_return_type",
        }

    parsed_params = parse_int_params(params)

    if parsed_params is None:
        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 0,
            "semantic_score": 0.0,
            "structural_score": structural_score(original_code, llm_code),
            "passed": 0,
            "total": 0,
            "status": "unsupported_params",
        }

    tests = make_tests(len(parsed_params))

    harness = generate_harness(
        original_code=original_code,
        llm_code=llm_code,
        func_name=func_name,
        params=parsed_params,
        tests=tests,
    )

    harness_path = sample_work_dir / "harness.c"
    harness_bin = sample_work_dir / "harness"

    harness_path.write_text(harness)

    compile_result = run([
        "gcc",
        "-O0",
        "-w",
        str(harness_path),
        "-o",
        str(harness_bin),
    ])

    if compile_result.returncode != 0:
        (sample_work_dir / "compile_error.txt").write_text(compile_result.stderr)

        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 0,
            "semantic_score": 0.0,
            "structural_score": structural_score(original_code, llm_code),
            "passed": 0,
            "total": len(tests),
            "status": "compile_error",
        }

    exec_result = run([str(harness_bin)], timeout=10)

    if exec_result.returncode != 0:
        (sample_work_dir / "runtime_error.txt").write_text(
            exec_result.stderr + "\n" + exec_result.stdout
        )

        return {
            "backend": backend,
            "transform": transform,
            "category": category,
            "sample": sample_name,
            "original_path": str(original_path),
            "llm_path": str(llm_path),
            "compile": 1,
            "semantic_score": 0.0,
            "structural_score": structural_score(original_code, llm_code),
            "passed": 0,
            "total": len(tests),
            "status": "runtime_error",
        }

    passed = 0
    total = 0

    for line in exec_result.stdout.splitlines():
        if line.startswith("PASSED="):
            parts = line.replace("PASSED=", "").replace("TOTAL=", "").split()
            passed = int(parts[0])
            total = int(parts[1])

    semantic = passed / total if total else 0.0
    struct = structural_score(original_code, llm_code)

    (sample_work_dir / "stdout.txt").write_text(exec_result.stdout)

    return {
        "backend": backend,
        "transform": transform,
        "category": category,
        "sample": sample_name,
        "original_path": str(original_path),
        "llm_path": str(llm_path),
        "compile": 1,
        "semantic_score": semantic,
        "structural_score": struct,
        "passed": passed,
        "total": total,
        "status": "done",
    }


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    rows = []

    for backend in BACKENDS:
        for transform in TRANSFORMS:
            for category in CATEGORIES:
                for i in range(1, SAMPLE_COUNT + 1):
                    sample_name = f"{category}_{i:02d}"

                    print(f"[+] Evaluation {backend}/{transform}/{category}/{sample_name}")

                    row = evaluate_sample(backend, transform, category, sample_name)
                    rows.append(row)

                    if row["status"] == "missing_llm_code":
                        print(f"    [SKIP] code LLM absent : {row['llm_path']}")
                    else:
                        print(
                            f"    [STATUS] {row['status']} | "
                            f"compile={row['compile']} | "
                            f"semantic={row['semantic_score']:.3f} | "
                            f"structural={row['structural_score']:.3f}"
                        )

    fieldnames = [
        "backend",
        "transform",
        "category",
        "sample",
        "original_path",
        "llm_path",
        "compile",
        "semantic_score",
        "structural_score",
        "passed",
        "total",
        "status",
    ]

    with RESULTS_CSV.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"[+] Résultats écrits dans {RESULTS_CSV}")


if __name__ == "__main__":
    main()
