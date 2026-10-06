USE ROLE ACCOUNTADMIN ; 

-- Création du file format ici qui permettra a snowflake de pouvoir lire les fichiers au format json 
CREATE FILE FORMAT IF NOT EXISTS JSON_TRANSACTION_FORMAT 
    TYPE = JSON 
    COMPRESSION = AUTO ; 

-- Création de la table qui va recevoir les données brutes 
CREATE TABLE IF NOT EXISTS RETAIL_PULSE_DB.BRONZE.BRZ_TRANSACTIONS (
    RAW_DATA VARIANT
) ;

SELECT CURRENT_ROLE(), CURRENT_DATABASE(), CURRENT_SCHEMA();