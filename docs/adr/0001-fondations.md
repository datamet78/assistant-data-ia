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

### 6. Région eu-north-1 (Stockholm)
**Contexte :** le compte a été créé avec la nouvelle expérience AWS par « projets ». AWS y attribue à chaque projet **une seule Région**, selon le pays de l'adresse de contact. Pour l'Europe, c'est `eu-north-1`.
**Choisi :** `eu-north-1`. Les données restent dans l'UE (RGPD).
**Écarté :** *eu-west-1 (Irlande)*, le choix initial, car elle offre en général les nouveaux services plus tôt. L'utiliser exigerait d'activer les « fonctionnalités avancées » (AWS Organizations), ce qui est inutile à ce stade.
**À vérifier :**
- étape 3 : les modèles Bedrock disponibles dans cette Région, avec les profils d'inférence `eu.` si besoin ;
- étape 4 : la disponibilité de S3 Vectors ;
- étape 3 : les fonctionnalités CloudFront qui créent des ressources hors Région (certificat pour un nom de domaine personnalisé, WAF) sont indisponibles. Le domaine par défaut `*.cloudfront.net` suffit.

### 6 bis. Plan gratuit AWS
Le compte est sur le **plan gratuit** : 100 $ de crédits, valable 6 mois au plus. À son expiration, le compte et ses ressources sont suspendus. Il faudra passer au plan payant avant cette échéance, ou plus tôt si un service nécessaire (par exemple Bedrock) est bloqué.

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
