import pandas as pd
from weasyprint import HTML

csv_file = "results/results.csv"
pdf_file = "tableau.pdf"

df = pd.read_csv(csv_file)

html = f"""
<html>
<head>
    <meta charset="utf-8">
    <style>
        @page {{
            size: A4 landscape;
            margin: 10mm;
        }}

        body {{
            font-family: Arial, sans-serif;
            margin: 0;
        }}

        h1 {{
            text-align: center;
            color: #222;
            font-size: 16px;
        }}

        table {{
            border-collapse: collapse;
            width: 100%;
            table-layout: fixed;
            font-size: 7px;
        }}

        th, td {{
            border: 1px solid #999;
            padding: 3px;
            text-align: left;
            vertical-align: top;
            word-wrap: break-word;
            overflow-wrap: anywhere;
        }}

        th {{
            background-color: #f2f2f2;
        }}

        tr:nth-child(even) {{
            background-color: #fafafa;
        }}
    </style>
</head>
<body>
    <h1>Evaluation Results with LLM</h1>
    {df.to_html(index=False)}
</body>
</html>
"""

HTML(string=html).write_pdf(pdf_file)
print(f"PDF généré : {pdf_file}")