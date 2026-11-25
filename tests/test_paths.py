"""Tests de dataia.paths.

pytest découvre automatiquement les fichiers "test_*.py" et les fonctions
"test_*". Chaque test vérifie un comportement précis avec "assert" : si la
condition est fausse, le test échoue, et le pipeline bloque la fusion.

Lancer en local :  pytest -v
"""

from datetime import date

import pytest

from dataia.paths import lake_key

# --- Cas nominaux : la fonction produit le bon chemin -----------------------


def test_cle_bronze():
    key = lake_key("bronze", "data-gouv", "dvf", date(2026, 11, 17), "dvf.csv")
    assert key == "bronze/source=data-gouv/dataset=dvf/ingestion_date=2026-11-17/dvf.csv"


# "parametrize" exécute le même test plusieurs fois avec des valeurs
# différentes : ici une fois pour "silver", une fois pour "gold".
@pytest.mark.parametrize("zone", ["silver", "gold"])
def test_autres_zones(zone):
    key = lake_key(zone, "data-gouv", "dvf", date(2026, 1, 5), "part-0.parquet")
    assert key.startswith(f"{zone}/")
    # Le mois et le jour sont bien complétés par des zéros (01, 05).
    assert "ingestion_date=2026-01-05" in key


# --- Cas d'erreur : la fonction refuse les entrées invalides -----------------
# "pytest.raises" vérifie qu'une exception est bien levée ; "match" vérifie
# que son message contient le texte attendu.


def test_zone_inconnue():
    with pytest.raises(ValueError, match="zone inconnue"):
        lake_key("platinum", "data-gouv", "dvf", date(2026, 1, 1), "f.csv")


@pytest.mark.parametrize(
    "source",
    [
        "Data-Gouv",  # majuscules
        "data_gouv",  # underscore
        "data/gouv",  # créerait un sous-dossier
        "",  # vide
        "-x",  # tiret en tête
    ],
)
def test_source_invalide(source):
    with pytest.raises(ValueError, match="source invalide"):
        lake_key("bronze", source, "dvf", date(2026, 1, 1), "f.csv")


@pytest.mark.parametrize(
    "filename",
    [
        "../secret",  # tentative de sortie du dossier
        "a b.csv",  # espace
        "",  # vide
        "..",  # dossier parent
    ],
)
def test_nom_de_fichier_invalide(filename):
    with pytest.raises(ValueError, match="nom de fichier invalide"):
        lake_key("bronze", "data-gouv", "dvf", date(2026, 1, 1), filename)
