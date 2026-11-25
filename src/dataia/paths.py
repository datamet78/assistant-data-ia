"""Conventions de nommage des fichiers dans le data lake.

Tous les fichiers du projet suivent le même schéma de chemin (« clé » S3) :

    <zone>/source=<source>/dataset=<jeu>/ingestion_date=<AAAA-MM-JJ>/<fichier>

Exemple :
    bronze/source=data-gouv/dataset=dvf/ingestion_date=2026-11-17/dvf.csv

Pourquoi ce format « clé=valeur » ?
    C'est le format « Hive ». Glue et Athena le reconnaissent automatiquement
    comme des PARTITIONS : une requête filtrée sur une date ne lit que le
    dossier de cette date. Moins de données lues = requête plus rapide et
    moins chère (Athena facture au volume lu).

Centraliser la règle dans une fonction évite que chaque script invente son
propre format, et permet de la tester.
"""

# Permet d'écrire les annotations de type modernes (ex. "str | None")
# quelle que soit la version de Python.
from __future__ import annotations

import re
from datetime import date

# Les trois zones du data lake (architecture « médaillon ») :
#   bronze : données brutes, telles que téléchargées
#   silver : nettoyées et typées, au format Parquet
#   gold   : agrégées, prêtes à être interrogées par l'IA
ZONES = ("bronze", "silver", "gold")

# Expressions régulières de validation (compilées une seule fois).
#
# _SLUG : minuscules et chiffres, groupes séparés par un tiret unique.
#   OK : "dvf", "data-gouv", "energie-2024"
#   KO : "Data-Gouv" (majuscules), "data_gouv" (underscore), "-x" (tiret
#        en tête), "a/b" (le "/" créerait un sous-dossier imprévu)
_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")

# _FILENAME : lettres, chiffres, point, tiret, underscore. Interdit les "/"
# et les espaces, ce qui bloque notamment les "../" (sortie de dossier).
_FILENAME = re.compile(r"^[A-Za-z0-9._-]+$")


def _check_slug(name: str, value: str) -> None:
    """Lève une ValueError si `value` n'est pas un slug valide.

    Le "_" en tête du nom indique une fonction interne au module.
    """
    if not _SLUG.fullmatch(value):
        raise ValueError(f"{name} invalide : {value!r} (minuscules, chiffres et tirets uniquement)")


def lake_key(
    zone: str,
    source: str,
    dataset: str,
    ingestion_date: date,
    filename: str,
) -> str:
    """Construit la clé S3 d'un fichier dans une zone du data lake.

    Args:
        zone: "bronze", "silver" ou "gold".
        source: origine des données, ex. "data-gouv".
        dataset: nom du jeu de données, ex. "dvf" (valeurs foncières).
        ingestion_date: jour où les données ont été collectées.
        filename: nom du fichier, ex. "dvf.csv".

    Returns:
        Le chemin complet, ex.
        "bronze/source=data-gouv/dataset=dvf/ingestion_date=2026-11-17/dvf.csv"

    Raises:
        ValueError: si un des paramètres ne respecte pas la convention.
    """
    # 1. Validation : on refuse tôt plutôt que d'écrire au mauvais endroit.
    if zone not in ZONES:
        raise ValueError(f"zone inconnue : {zone!r} (attendu : {', '.join(ZONES)})")
    _check_slug("source", source)
    _check_slug("dataset", dataset)
    if not _FILENAME.fullmatch(filename) or filename in {".", ".."}:
        raise ValueError(f"nom de fichier invalide : {filename!r}")

    # 2. Construction. date.isoformat() donne toujours "AAAA-MM-JJ",
    #    un format qui se trie correctement par ordre alphabétique.
    return (
        f"{zone}/source={source}/dataset={dataset}/"
        f"ingestion_date={ingestion_date.isoformat()}/{filename}"
    )
