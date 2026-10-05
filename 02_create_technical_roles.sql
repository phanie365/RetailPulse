-- CREATION DES ROLES TECHNIQUES SUR LE SCHEMA BRONZE 
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_BRONZE_SR ; -- lecture sur les tables et les vues du schema bronze
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_BRONZE_SW;  -- insertion , modification et suppression des données bronzze 
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_BRONZE_SFULL; -- Lecture ,ecriture et creation des tables , vues dans le schea bronze 

--CREATTION DES ROLES TECHNIQUES SUR LE SCHEMA SILVER 
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_SILVER_SR ; -- lecture sur les tables et les vues du schema SILVER
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_SILVER_SW;  -- insertion , modification et suppression des données SILVER 
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_SILVER_SFULL; -- Lecture ,ecriture et creation des tables , vues dans le schea SILVER 

--CREATTION DES ROLES TECHNIQUES SUR LE SCHEMA GOLD
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_GOLD_SR ; -- lecture sur les tables et les vues du schema GOLD
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_GOLD_SW;  -- insertion , modification et suppression des données GOLD
CREATE ROLE IF NOT EXISTS RETAIL_PULSE_GOLD_SFULL; -- Lecture ,ecriture et creation des tables , vues dans le schea GOLD 