# Can LLM Break Obfuscation?

Projet de recherche mené dans le cadre du M1 SLM à l'Université de Rennes (ISTIC), sous la direction du **Pr. Mohamed Sabt**.

---

###  Le constat de départ
En 2026, l'étude NDSS de Basque et al. a démontré l'efficacité du binôme humain-LLM pour la rétro-ingénierie. Cependant, leurs travaux laissaient une zone d'ombre majeure : le comportement de ces modèles face à du code volontairement obfusqué (flatte de flux de contrôle, virtualisation, encodage arithmétique).

Les outils de désobfuscation traditionnels fonctionnent très bien sur des motifs précis, mais s'effondrent dès que plusieurs techniques sont combinées. Notre hypothèse était la suivante : **un modèle de langage, de par sa compréhension sémantique du code, peut-il dépasser ces limites et restituer la logique d'un binaire obfusqué ?**

---

###  L'approche expérimentale
Pour tester cette hypothèse sans biais, nous avons mis en place la méthodologie suivante :

- **Un dataset varié :** Ecriture de binaires C couvrant plusieurs structures (opérations arithmétiques, boucles, appels de fonctions) obfusquées via **Tigress**, **Movfuscator** (code exécuté quasi exclusivement avec des instructions `mov`) et **Kovid** (passes LLVM/GCC).
- **Évaluation en boîte noire :** Le code décompilé via **Ghidra** a été soumis à **Gemini 3.1 Pro** avec un prompt minimaliste, sans lui indiquer l'outil d'obfuscation utilisé ni le comportement attendu.
- **Mesure objective :** Remplacement de l'évaluation humaine subjective par la métrique **CodeBERTScore**, en établissant un seuil d'utilité opérationnelle à **0,70**.
- **Cas réel (Go Malware) :** Validation de la méthode sur un binaire de malware écrit en Go (~12 000 fonctions) dont la table `pcintab` avait été altérée pour bloquer l'analyse.

---

### 📊 Ce que nous avons découvert
Les résultats montrent que les LLM constituent un **accélérateur remarquable pour l'analyse**, mais pas une solution miracle.

1. **L'IA face aux obfuscateurs :** Le modèle a obtenu de très bons résultats sur Movfuscator (scores entre 0,83 et 0,90) et Kovid (jusqu'à 0,86). En revanche, **Tigress s'est imposé comme le plus résistant** : la combinaison de ses cinq transformations a fait chuter la compréhension du LLM autour de 0,76.
2. **L'apport sur le cas réel :** Sur le malware Go, l'IA a permis d'accélérer la réparation des scripts Ghidra obsolètes, d'analyser la structure altérée et d'isoler rapidement les phases de chiffrement ainsi que les communications C2.
3. **Les limites observées :** L'illusion de confiance (hallucinations sur du code très dense), la perte de précision au fur et à mesure que la complexité augmente, et la résistance des empilements d'obfuscations complexes.

> **En résumé :** L'IA ne remplace pas l'expert en reverse engineering, mais elle peut drastiquement l'assister sur les phases les plus chronophages de l'analyse.

---

### 🎤 Restitution & Présentation
Les résultats et la méthodologie de ce projet ont été présentés lors de la journée d'études **« AI and Cybersecurity »** organisée par le Cluster **SequoIA**.

---

### 👨‍💻 Mon rôle dans le projet
Au sein de l'équipe de 5 étudiants, je me suis particulièrement investi sur :
- La construction et l'automatisation du pipeline de tests et d'évaluation du dataset.
- L'obfuscation avec Tigress avec plusieurs téchniques différentes. Nous nous sommes divisé le dataset de 60 programmes en 4.
- La désobfuscation manuel de ma partie du dataset de programes.
- La désobfuscation avec L'IA des programmes dont j'étais responsable.
- L'évaluation avec notre méthode de mesure de l'efficacité du LLM sur mes programmes.
- La rédaction du rapport et la préparation de la présentation finale.

---

*Rapport complet de recherche disponible dans le dépôt (`Can_LLM_Break_Obfuscation.pdf`).*
