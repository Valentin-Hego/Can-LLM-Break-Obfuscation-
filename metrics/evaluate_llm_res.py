#!/usr/bin/env python3
from __future__ import annotations

import csv
import random
import re
import subprocess
from dataclasses import dataclass, asdict
from pathlib import Path


# ============================================================
# Configuration
# ============================================================

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

RANDOM_SEED = 123456
TEST_COUNT_RANDOM = 500
TEST_COUNT_FIXED = 100


# ============================================================
# Modèle de résultat
# ============================================================

@dataclass
class EvalResult:
    backend: str
    transform: str
    category: str
    sample: str
    original_path: str
    llm_path: str
    compile: int
    semantic_score: float
    structural_score: float
    passed: int
    total: int
    status: str


# ============================================================
# Utilitaires
# ============================================================

def run_command(cmd: list[str], timeout: int = 20) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )

def run(cmd: list[str], timeout: int = 20) -> subprocess.CompletedProcess:
    return run_command(cmd, timeout)

def read_text(path: Path) -> str:
    return path.read_text(errors="ignore")


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def clean_llm_code(code: str) -> str:
    """
    Nettoie une sortie LLM :
    - retire les blocs ```c ... ```
    - retire les blocs ``` ... ```
    """
    code = code.strip()

    if code.startswith("```"):
        lines = code.splitlines()

        if lines:
            lines = lines[1:]

        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]

        code = "\n".join(lines).strip()

    if code.startswith("c\n"):
        code = code[2:].strip()

    return code


# ============================================================
# Détection de fonction
# ============================================================

FUNCTION_PATTERN = re.compile(
    r'^[ \t]*'
    r'(int|long|short|char|void|unsigned\s+int|signed\s+int)'
    r'[ \t\*]+'
    r'([a-zA-Z_][a-zA-Z0-9_]*)'
    r'[ \t]*\(([^)]*)\)',
    re.MULTILINE,
)


@dataclass
class FunctionInfo:
    return_type: str
    name: str
    params: str
    signature: str


def detect_function(code: str) -> FunctionInfo | None:
    """
    Détecte la première fonction non-main dans le code source original.
    """
    for match in FUNCTION_PATTERN.finditer(code):
        return_type = match.group(1).strip()
        name = match.group(2).strip()
        params = match.group(3).strip()
        signature = match.group(0).strip()

        if name == "main":
            continue

        return FunctionInfo(
            return_type=return_type,
            name=name,
            params=params,
            signature=signature,
        )

    return None


def parse_int_params(params: str) -> list[str] | None:
    """
    Accepte uniquement les paramètres de type int simples.

    Exemples acceptés :
    - int x
    - int a, int b
    - unsigned int x

    Exemples refusés :
    - int *arr
    - char *s
    - float x
    """
    params = params.strip()

    if params == "" or params == "void":
        return []

    parsed_params = []

    for param in params.split(","):
        param = param.strip()

        if "*" in param:
            return None

        if re.search(r"\bint\b", param):
            parsed_params.append(param)
        else:
            return None

    return parsed_params


# ============================================================
# Génération des tests
# ============================================================

def make_tests(param_count: int) -> list[tuple[int, ...]]:
    """
    Génère des tests déterministes pour les fonctions int.
    """
    if param_count == 0:
        return [()]

    fixed_values = [
        -1000, -100, -42, -10, -3, -2, -1,
        0,
        1, 2, 3, 10, 42, 100, 1000,
    ]

    random.seed(RANDOM_SEED)

    tests: list[tuple[int, ...]] = []

    for _ in range(TEST_COUNT_FIXED):
        tests.append(tuple(random.choice(fixed_values) for _ in range(param_count)))

    for _ in range(TEST_COUNT_RANDOM):
        tests.append(tuple(random.randint(-1000, 1000) for _ in range(param_count)))

    return deduplicate_tests(tests)


def deduplicate_tests(tests: list[tuple[int, ...]]) -> list[tuple[int, ...]]:
    seen = set()
    unique = []

    for test in tests:
        if test not in seen:
            seen.add(test)
            unique.append(test)

    return unique


# ============================================================
# Génération du harness C
# ============================================================

def generate_tests_array(tests: list[tuple[int, ...]], param_count: int) -> str:
    rows = []

    for test in tests:
        if param_count == 0:
            rows.append("{0}")
        else:
            rows.append("{" + ", ".join(str(value) for value in test) + "}")

    return ",\n        ".join(rows)


def generate_function_calls(func_name: str, param_count: int) -> tuple[str, str, str]:
    """
    Retourne :
    - déclaration du tableau de tests
    - appel de la fonction originale
    - appel de la fonction LLM
    """
    if param_count == 0:
        return (
            "int tests[][1]",
            f"original_{func_name}()",
            f"llm_{func_name}()",
        )

    args = ", ".join(f"tests[i][{index}]" for index in range(param_count))

    return (
        f"int tests[][{param_count}]",
        f"original_{func_name}({args})",
        f"llm_{func_name}({args})",
    )


def generate_harness(
    original_code: str,
    llm_code: str,
    func_name: str,
    params: list[str],
    tests: list[tuple[int, ...]],
) -> str:
    param_count = len(params)

    tests_c = generate_tests_array(tests, param_count)
    array_decl, call_original, call_llm = generate_function_calls(func_name, param_count)

    return f"""
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
        int original_result = {call_original};
        int llm_result = {call_llm};

        if (original_result == llm_result) {{
            passed++;
        }} else {{
            printf(
                "FAIL test=%d original=%d llm=%d\\n",
                i,
                original_result,
                llm_result
            );
        }}
    }}

    printf("PASSED=%d TOTAL=%d\\n", passed, total);
    return 0;
}}
"""


# ============================================================
# Métriques structurelles
# ============================================================

def count_complexity_features(code: str) -> dict[str, int]:
    return {
        "lines": count_non_empty_lines(code),
        "if": count_keyword(code, "if"),
        "for": count_keyword(code, "for"),
        "while": count_keyword(code, "while"),
        "switch": count_keyword(code, "switch"),
        "return": count_keyword(code, "return"),
        "operators": count_operators(code),
    }


def count_non_empty_lines(code: str) -> int:
    return len([line for line in code.splitlines() if line.strip()])


def count_keyword(code: str, keyword: str) -> int:
    return len(re.findall(rf"\b{keyword}\b", code))


def count_operators(code: str) -> int:
    operators = ["+", "-", "*", "/", "%", "^", "&", "|", "<<", ">>"]
    return sum(code.count(op) for op in operators)


def structural_score(original_code: str, llm_code: str) -> float:
    original_features = count_complexity_features(original_code)
    llm_features = count_complexity_features(llm_code)

    scores = []

    for key in original_features:
        original_value = original_features[key]
        llm_value = llm_features[key]

        if original_value == 0 and llm_value == 0:
            scores.append(1.0)
            continue

        score = 1.0 - abs(original_value - llm_value) / max(original_value, llm_value, 1)
        scores.append(max(0.0, score))

    return sum(scores) / len(scores)


# ============================================================
# Évaluation d’un sample
# ============================================================

def make_result(
    backend: str,
    transform: str,
    category: str,
    sample: str,
    original_path: Path,
    llm_path: Path,
    status: str,
    compile_ok: int = 0,
    semantic: float = 0.0,
    structural: float = 0.0,
    passed: int = 0,
    total: int = 0,
) -> EvalResult:
    return EvalResult(
        backend=backend,
        transform=transform,
        category=category,
        sample=sample,
        original_path=str(original_path),
        llm_path=str(llm_path),
        compile=compile_ok,
        semantic_score=semantic,
        structural_score=structural,
        passed=passed,
        total=total,
        status=status,
    )


def evaluate_sample(
    backend: str,
    transform: str,
    category: str,
    sample_name: str,
) -> EvalResult:
    original_path = CODE_BASE_DIR / category / f"{sample_name}.c"
    llm_path = LLM_CODE_DIR / backend / transform / category / f"{sample_name}.c"

    sample_work_dir = WORK_DIR / backend / transform / category / sample_name
    sample_work_dir.mkdir(parents=True, exist_ok=True)

    if not original_path.exists():
        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="missing_original",
        )

    if not llm_path.exists():
        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="missing_llm_code",
        )

    original_code = read_text(original_path)
    llm_code = clean_llm_code(read_text(llm_path))
    write_text(llm_path, llm_code)

    function = detect_function(original_code)

    if function is None:
        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="function_not_detected",
            structural=structural_score(original_code, llm_code),
        )

    if function.return_type != "int":
        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="unsupported_return_type",
            structural=structural_score(original_code, llm_code),
        )

    parsed_params = parse_int_params(function.params)

    if parsed_params is None:
        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="unsupported_params",
            structural=structural_score(original_code, llm_code),
        )

    tests = make_tests(len(parsed_params))

    harness = generate_harness(
        original_code=original_code,
        llm_code=llm_code,
        func_name=function.name,
        params=parsed_params,
        tests=tests,
    )

    harness_path = sample_work_dir / "harness.c"
    harness_bin = sample_work_dir / "harness"

    write_text(harness_path, harness)

    compile_result = compile_harness(harness_path, harness_bin)

    if compile_result.returncode != 0:
        write_text(sample_work_dir / "compile_error.txt", compile_result.stderr)

        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="compile_error",
            structural=structural_score(original_code, llm_code),
            total=len(tests),
        )

    exec_result = run_harness(harness_bin)

    if exec_result.returncode != 0:
        write_text(
            sample_work_dir / "runtime_error.txt",
            exec_result.stderr + "\n" + exec_result.stdout,
        )

        return make_result(
            backend, transform, category, sample_name,
            original_path, llm_path,
            status="runtime_error",
            compile_ok=1,
            structural=structural_score(original_code, llm_code),
            total=len(tests),
        )

    passed, total = parse_harness_result(exec_result.stdout)
    semantic = passed / total if total else 0.0
    structural = structural_score(original_code, llm_code)

    write_text(sample_work_dir / "stdout.txt", exec_result.stdout)

    return make_result(
        backend, transform, category, sample_name,
        original_path, llm_path,
        status="done",
        compile_ok=1,
        semantic=semantic,
        structural=structural,
        passed=passed,
        total=total,
    )


def compile_harness(harness_path: Path, harness_bin: Path) -> subprocess.CompletedProcess:
    return run([
        "gcc",
        "-O0",
        "-w",
        str(harness_path),
        "-o",
        str(harness_bin),
    ])


def run_harness(harness_bin: Path) -> subprocess.CompletedProcess:
    return run([str(harness_bin)], timeout=10)


def parse_harness_result(stdout: str) -> tuple[int, int]:
    for line in stdout.splitlines():
        if line.startswith("PASSED="):
            parts = line.replace("PASSED=", "").replace("TOTAL=", "").split()
            return int(parts[0]), int(parts[1])

    return 0, 0


# ============================================================
# Boucle principale
# ============================================================

def iter_expected_samples():
    for backend in BACKENDS:
        for transform in TRANSFORMS:
            for category in CATEGORIES:
                for index in range(1, SAMPLE_COUNT + 1):
                    sample_name = f"{category}_{index:02d}"
                    yield backend, transform, category, sample_name


def write_results(rows: list[EvalResult]) -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

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

        for row in rows:
            writer.writerow(asdict(row))


def print_result(row: EvalResult) -> None:
    if row.status == "missing_llm_code":
        print(f"    [SKIP] code LLM absent : {row.llm_path}")
        return

    print(
        f"    [STATUS] {row.status} | "
        f"compile={row.compile} | "
        f"semantic={row.semantic_score:.3f} | "
        f"structural={row.structural_score:.3f}"
    )


def main() -> None:
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    rows: list[EvalResult] = []

    for backend, transform, category, sample_name in iter_expected_samples():
        print(f"[+] Evaluation {backend}/{transform}/{category}/{sample_name}")

        row = evaluate_sample(backend, transform, category, sample_name)
        rows.append(row)

        print_result(row)

    write_results(rows)

    print(f"[+] Résultats écrits dans {RESULTS_CSV}")


if __name__ == "__main__":
    main()