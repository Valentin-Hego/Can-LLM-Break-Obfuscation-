
import pandas as pd
from weasyprint import HTML

# Fichier d'entrée
csv_file = "results/results.csv"
pdf_file = "tableau.pdf"

# Lire le CSV
df = pd.read_csv(csv_file)

# Limiter éventuellement le nombre de lignes affichées
# df = df.head(50)

html = f"""
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 30px;
        }}
        h1 {{
            text-align: center;
            color: #222;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            font-size: 12px;
        }}
        th, td {{
            border: 1px solid #999;
            padding: 8px;
            text-align: left;
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
    <h1>Tableau CSV</h1>
    {df.to_html(index=False)}
</body>
</html>
"""

HTML(string=html).write_pdf(pdf_file)
print(f"PDF généré : {pdf_file}")
