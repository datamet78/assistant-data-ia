# Assistant data & IA sur AWS

> Interroger ses données et ses documents en français, sans passer par un analyste.

## Le problème
Une PME ou une collectivité dispose de données (prix immobiliers, consommation d'énergie…) et de documents (rapports, méthodologies), mais chaque question demande l'intervention d'un analyste : extraction, requête SQL, mise en forme. Les délais s'allongent et les décisions se prennent sans les chiffres.

## La solution
Une plateforme qui :
1. **collecte automatiquement** des données publiques (data.gouv.fr) ;
2. les **organise** dans un data lake en trois zones (brut → nettoyé → prêt à l'usage) ;
3. permet de les **interroger en français** : l'IA traduit la question en SQL, exécute la requête et formule la réponse ;
4. répond aussi à partir de **documents**, en citant ses sources (RAG).

Le tout est déployé automatiquement (CI/CD), sécurisé, hébergé en Europe, et coûte **quelques dollars par mois**.

## Architecture
*(schéma à venir)*

| Brique | Services AWS |
|---|---|
| Déploiement | GitHub Actions, Terraform, OIDC |
| Ingestion | Lambda, EventBridge |
| Data lake | S3 (bronze / silver / gold), Glue Data Catalog, Athena |
| IA | Bedrock (text-to-SQL), Knowledge Base + S3 Vectors (RAG), Guardrails |
| Interface | S3 + CloudFront, API Gateway + Lambda |

## Avancement
- [x] **Étape 1 — Fondations** : dépôt, Terraform, pipeline CI/CD, OIDC, alerte budget
- [ ] Étape 2 — Data : ingestion, data lake, Glue, Athena
- [ ] Étape 3 — IA : text-to-SQL, API, page web
- [ ] Étape 4 — RAG : documents, Guardrails, évaluation
- [ ] Étape 5 — Extension Databricks

## Organisation du dépôt
```
bootstrap/            Terraform appliqué une fois à la main (state, OIDC, rôles, budget)
infra/                Terraform déployé par le pipeline
src/dataia/           Code Python
tests/                Tests Python (pytest)
.github/workflows/    Pipeline CI/CD
docs/                 Décisions d'architecture (ADR) et guides
```

## Sécurité
- Aucune clé AWS stockée : GitHub s'authentifie par **OIDC** avec des identifiants temporaires.
- Deux rôles distincts : **lecture seule** pour les pull requests, **déploiement** réservé à `main`.
- Droits de déploiement limités aux ressources du projet (moindre privilège).
- Buckets chiffrés, versionnés, sans accès public, HTTPS obligatoire.
- Données hébergées en Europe (`eu-north-1`, Stockholm).

## Coûts
Alerte budget à 10 $/mois (e-mails à 50 %, 80 % et 100 % prévu). Estimation détaillée et section FinOps à venir.

## Démarrer
Voir [docs/guide-etape-1.md](docs/guide-etape-1.md).

## Décisions d'architecture
- [ADR 0001 — Fondations](docs/adr/0001-fondations.md)
