# RetailPulse : Modern Data Warehouse sur Snowflake

Projet d'apprentissage construit autour de transactions de vente au format JSON. Il met en pratique l'ingestion de données semi-structurées, une architecture Bronze / Silver / Gold, les transformations dbt, le CDC avec les streams et l'orchestration avec les tasks Snowflake.

## Objectif

Partir d'événements de vente contenant notamment `transaction_id`, `customer_info`, `items`, `total_amount` et `event_timestamp`, puis produire une table analytique exploitable pour suivre les ventes.

## Préparation de l'environnement et des accès

Le projet démarre par la création du warehouse `RETAIL_PULSE_WH`, de la base `RETAIL_PULSE_DB` et des trois schémas : `BRONZE` pour les événements bruts, `SILVER` pour les données préparées et `GOLD` pour les données analytiques.

### Rôles et droits d'accès

Deux familles de rôles structurent les autorisations :

| Famille | Fonction dans le projet | Exemple |
| --- | --- | --- |
| **Rôles opérationnels (techniques)** | Portent les privilèges sur les objets d'un schéma. Ils sont créés par zone et par niveau d'accès. | `SR` pour lire, `SW` pour écrire, `SFULL` pour gérer les objets du schéma. |
| **Rôles fonctionnels** | Rassemblent plusieurs rôles opérationnels pour répondre à un besoin métier, puis sont attribués aux utilisateurs. | `RETAIL_DATA_ANALYST`, qui hérite de la lecture de Silver et Gold. |

Les rôles opérationnels sont définis pour les schémas `BRONZE`, `SILVER` et `GOLD`. Leur nom décrit l'intention, mais **Snowflake n'attribue aucun privilège à partir de `SR`, `SW` ou `SFULL`** : ce sont les commandes `GRANT` qui déterminent ce que chaque rôle peut faire.

| Niveau | Privilèges accordés dans le périmètre du schéma | Effet |
| --- | --- | --- |
| `SR` : lecture | `USAGE` sur la base et le schéma ; `SELECT` sur les tables et vues existantes (`ALL`) et sur celles créées ensuite (`FUTURE`). | Consulter les données du schéma. `USAGE` seul ne permet pas de lire les lignes. |
| `SW` : écriture | `USAGE` sur la base et le schéma ; `INSERT`, `UPDATE` et `DELETE` sur les tables existantes et futures, selon les besoins. | Modifier les lignes des tables autorisées. Ces droits n'impliquent pas automatiquement `SELECT` ; celui-ci doit être accordé si l'écriture nécessite aussi la lecture. |
| `SFULL` : accès étendu au schéma | Droits de lecture et d'écriture, plus les privilèges de création nécessaires sur le schéma, par exemple `CREATE TABLE` et `CREATE VIEW`. | Créer et utiliser les objets prévus dans ce schéma. Le libellé « full » ne donne pas à lui seul `OWNERSHIP`, ni le droit de créer des bases ou des warehouses. |

`ALL TABLES` et `ALL VIEWS` couvrent les objets déjà présents ; `FUTURE TABLES` et `FUTURE VIEWS` couvrent ceux créés ultérieurement. Le contrôle des accès suit donc la chaîne **base → schéma → objet**. Pour les vues, c'est `SELECT` qui sert à la consultation ; les privilèges d'écriture concernent les tables. Si un schéma est en mode *managed access*, l'attribution de droits sur ses objets est réservée au propriétaire du schéma ou à un rôle autorisé à gérer les grants.

Le rôle fonctionnel `RETAIL_DATA_ANALYST` hérite des rôles `SR` de `SILVER` et de `GOLD`, sans rôle de lecture sur `BRONZE`. Il reçoit séparément `USAGE` sur `RETAIL_PULSE_WH` pour exécuter des requêtes. Il peut ensuite être attribué à un utilisateur ; les droits de lecture proviennent de l'héritage des rôles opérationnels, sans répéter tous les `GRANT` sur les tables.

## Architecture des données

| Zone | Objet principal | Rôle |
| --- | --- | --- |
| Bronze | `RETAIL_PULSE_DB.BRONZE.BRZ_TRANSACTIONS` | Conserve chaque événement JSON dans `RAW_DATA VARIANT`. |
| Silver | Modèle dbt `slv_transactions` | Extrait et nettoie les attributs utiles ; déplie `items` avec `LATERAL FLATTEN`. |
| Silver | `RETAIL_PULSE_DB.SILVER.TRANSACTION_DELTA` | Conserve les nouvelles lignes capturées depuis le stream pour le traitement incrémental. |
| Gold | Modèle dbt `fact_sales` | Produit la table de faits des ventes et ses indicateurs métier. |

## Ingestion

Les fichiers `.json.gz` sont déposés dans le stage interne `RETAIL_PULSE_DB.BRONZE.STG_TRANSACTIONS_INTERNAL`. Le format de fichier JSON indique à Snowflake comment décoder les documents et leur compression. La première ingestion a été réalisée avec `COPY INTO` : 500 événements ont été chargés dans la table Bronze. La colonne `RAW_DATA` permet d'interroger les champs imbriqués sans perdre le JSON d'origine.

## Transformations dbt

dbt lit le JSON chargé en Bronze, prépare les transactions en Silver, puis construit la table analytique en Gold. Chaque fichier contribue à une étape précise :

| Fichier | À quoi il sert dans RetailPulse |
| --- | --- |
| `dbt_project.yml` | Déclare le projet, les dossiers de modèles et leurs réglages par défaut. Le dossier Silver est configuré pour produire des **vues**, et le dossier Gold porte les réglages des modèles analytiques. La configuration locale de `fact_sales.sql` remplace ce défaut pour produire une **table incrémentale**. Les schémas cibles `SILVER` et `GOLD` sont déclarés ici pour leurs dossiers respectifs. |
| `profiles.yml` | Définit la cible dbt (`dev`) et le contexte de connexion à Snowflake : rôle, warehouse `RETAIL_PULSE_WH`, base `RETAIL_PULSE_DB`, schéma par défaut et nombre de threads. Le schéma du profil est un **défaut**, pas la destination finale imposée à tous les modèles. |
| `models/source.yml` | Déclare les tables Snowflake déjà existantes comme **sources** dbt, notamment `BRONZE.BRZ_TRANSACTIONS` et la table de changements `SILVER.TRANSACTION_DELTA`. Les modèles peuvent ainsi les appeler avec `source(...)`, documenter leurs colonnes et déclarer leurs dépendances. |
| `macros/generate_schema_name.sql` | Personnalise le calcul du schéma cible. La macro permet d'écrire directement les modèles dans `SILVER` et `GOLD`, au lieu de préfixer ces noms avec le schéma par défaut du profil. |
| `models/.../slv_transactions.sql` | Modèle Silver : extrait depuis `RAW_DATA` l'identifiant de transaction, l'identifiant client, le pays, le montant et la date ; utilise `LATERAL FLATTEN` pour calculer le nombre d'articles par commande. Il est matérialisé en **vue**. |
| `models/.../fact_sales.sql` | Modèle Gold : s'appuie sur la préparation Silver, applique les règles métier comme la normalisation du pays et une catégorie de commande, puis alimente la table de faits. Il est configuré en **incrémental**, avec `transaction_id` comme `unique_key` et une stratégie de type `MERGE`. |

Les chemins `models/.../` indiquent le dossier correspondant dans le projet dbt ; le nom du modèle est celui du fichier `.sql`. `source(...)` référence une table déclarée dans `source.yml`, tandis que `ref('slv_transactions')` permet à Gold de dépendre du modèle Silver. La première exécution crée les objets ; les exécutions suivantes de `fact_sales` ne traitent que les données prévues par sa logique incrémentale. La table `SILVER.TRANSACTION_DELTA` conserve les nouvelles lignes capturées par la task Snowflake entre deux exécutions dbt.

Les modèles sont développés dans un workspace Snowflake lié à Git. Pour l'exécution par une task, les changements Git et dbt doivent être déployés dans l'objet dbt Snowflake utilisé par cette task ; un push Git seul ne met pas cet objet à jour.

## CDC et orchestration

1. Le stream `RETAIL_PULSE_DB.BRONZE.STR_BRZ_TRANSACTIONS` suit les nouvelles lignes insérées en Bronze.
2. La task planifiée `RETAIL_PULSE_DB.SILVER.TSK_CAPTURE_TRANSACTIONS` vérifie le stream toutes les heures et écrit les nouvelles lignes dans `SILVER.TRANSACTION_DELTA`.
3. Après une capture réussie, la task dépendante `RETAIL_PULSE_DB.SILVER.TSK_BUILD_FACT_SALES` exécute le projet dbt déployé pour alimenter `fact_sales`.

Les deux tasks ont été activées (`started`). Une task activée continue de fonctionner côté Snowflake même quand l'interface est fermée. Le stream enregistre les changements ; il n'exécute pas lui-même de traitement planifié.

Pour contrôler la configuration :

```sql
SHOW TASKS IN SCHEMA RETAIL_PULSE_DB.SILVER;

SELECT SYSTEM$STREAM_HAS_DATA(
    'RETAIL_PULSE_DB.BRONZE.STR_BRZ_TRANSACTIONS'
) AS HAS_NEW_DATA;
```

Un état `started` confirme l'activation, mais l'historique des exécutions doit être consulté pour confirmer qu'un cycle complet a effectivement alimenté Gold.

## Fonctions Snowflake explorées

- **VARIANT et `LATERAL FLATTEN`** : lecture des objets et tableaux JSON.
- **Streams et tasks** : suivi des nouvelles lignes et traitement planifié.
- **Time Travel** : comparaison de l'état de la table de faits avant et après une mise à jour de test.
- **Zero-Copy Clone** : création d'une base de test `RETAIL_PULSE_DB_DEV` à partir de la base principale.
- **RBAC** : rôles opérationnels par schéma et rôle fonctionnel `RETAIL_DATA_ANALYST` pour la consultation des données Silver et Gold.
