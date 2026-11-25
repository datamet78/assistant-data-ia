# ADR 0001 — Fondations : IaC, CI/CD et accès à AWS

- **Statut :** accepté
- **Date :** 2026-11-17

## Contexte
Le projet doit être reproductible, déployé sans intervention manuelle, sécurisé dès le départ et peu coûteux. Il sert aussi de démonstration en entretien : chaque choix doit pouvoir être justifié.

## Décisions

### 1. Terraform pour l'infrastructure as code
**Choisi :** Terraform.
**Écartés :**
- *AWS CDK* : très bien intégré à AWS, mais spécifique à AWS. Terraform est plus demandé sur le marché, et réutilisable ailleurs (Databricks a son provider Terraform).
- *CloudFormation brut* : verbeux, et moins répandu dans les offres d'emploi.

### 2. State dans S3, verrou natif S3
**Choisi :** backend S3 avec `use_lockfile = true` (Terraform ≥ 1.10).
**Écarté :** *table DynamoDB pour le verrou* : c'était l'ancienne méthode, désormais dépréciée. Une ressource de moins à gérer.

### 3. Bootstrap séparé, appliqué à la main
Le bucket du state, la fédération OIDC et les rôles IAM sont créés depuis le poste de l'administrateur, avec un state local.
**Pourquoi :** le pipeline a besoin de ces ressources pour exister (problème de l'œuf et de la poule). C'est aussi une **séparation des pouvoirs** : le pipeline ne peut pas élargir ses propres droits.

### 4. OIDC plutôt que des clés d'accès
**Choisi :** fédération OIDC GitHub → AWS, avec des identifiants temporaires (1 h).
**Écarté :** *clés d'accès IAM stockées dans les secrets GitHub* : elles sont longue durée, peuvent fuiter et doivent être renouvelées.

### 5. Deux rôles : plan et apply
| Rôle | Qui peut l'endosser | Droits |
|---|---|---|
| `plan` | pull requests et `main` du dépôt | lecture seule (`ReadOnlyAccess`) + state |
| `apply` | `main` uniquement | ressources nommées `dataia-<compte>-lake*` + state |

**Compromis assumé :** `ReadOnlyAccess` est large (il donne notamment la lecture des objets S3). Le risque est limité ici, car il s'agit de données publiques et d'un compte dédié au projet. Une évolution possible consiste à restreindre ce rôle aux seuls services du projet.

### 6. Région eu-west-1 (Irlande)
**Choisi :** `eu-west-1`.
**Écarté :** *eu-west-3 (Paris)* : plus proche, mais les nouveaux services (Bedrock, S3 Vectors) arrivent en général d'abord en Irlande ou à Francfort. Dans les deux cas, les données restent dans l'UE (RGPD).
**À vérifier à l'étape 4 :** la disponibilité de S3 Vectors et des modèles Bedrock visés dans cette région.

### 7. Chiffrement SSE-S3
**Choisi :** SSE-S3 (AES-256, clés gérées par AWS, gratuit).
**Écarté :** *SSE-KMS avec une clé dédiée* : environ 1 $/mois par clé, plus le coût des requêtes. Utile si un audit exige la maîtrise des clés, ce qui n'est pas nécessaire pour des données publiques.

### 8. Alerte budget
Un budget de 10 $/mois, avec des alertes à 50 % et 80 % du réel, et à 100 % du prévisionnel.
**Limite connue :** c'est une alerte, pas un plafond. Arrêter automatiquement les services (Budget Actions) est une option à étudier plus tard.

## Conséquences
- Toute modification d'infrastructure passe par une pull request, avec un plan visible avant la fusion.
- Ajouter un nouveau service AWS demande d'abord d'élargir le rôle `apply` dans `bootstrap/`, de façon consciente et manuelle.
- Le state local du bootstrap doit être sauvegardé hors du dépôt.
