SELECT *
FROM italy_staging;

-- clean whitespace
UPDATE italy_staging
SET region = TRIM(region);

-- Fix Puglia and Trento Data
SELECT *
FROM italy_staging
WHERE region = "Puglia";

UPDATE italy_staging
SET agriculture = 2575
WHERE region = "Puglia" AND Year = 2023;

UPDATE italy_staging
SET industry = 14705.8
WHERE region = "Puglia" and `year` = 2022;

SELECT *
FROM italy_staging
WHERE region = "Provincia Autonoma Trento";

UPDATE italy_staging
SET services = 15266.7
WHERE region = "Provincia Autonoma Trento" AND `year` = 2023;

-- Remove commas, fix data types

UPDATE italy_staging
SET gdp = REPLACE(gdp, ',', '');

ALTER TABLE italy_staging
MODIFY COLUMN gdp DECIMAL(15,1);

UPDATE italy_staging
SET agriculture = REPLACE(agriculture, ',', '');

ALTER TABLE italy_staging
MODIFY COLUMN agriculture DECIMAL(15,1);

UPDATE italy_staging
SET industry = REPLACE(industry, ',', '');

ALTER TABLE italy_staging
MODIFY COLUMN industry DECIMAL(15,1);

UPDATE italy_staging
SET services = REPLACE(services, ',', '');

ALTER TABLE italy_staging
MODIFY COLUMN services DECIMAL(15,1);

-- Add Percent Change Columns
CREATE TABLE italy_staging2 AS 
SELECT t2.`year`, t2.region, 
((t2.gdp - t1.gdp)/t1.gdp) * 100 AS gdp_change,
((t2.agriculture - t1.agriculture)/t1.agriculture) * 100 as agri_change,
((t2.industry - t1.industry)/t1.industry) * 100 as ind_change,
((t2.services - t1.services)/t1.services) * 100 as serv_change
FROM italy_staging t1
JOIN italy_staging t2
	ON t1.region = t2.region
WHERE t1.year = 2022 AND t2.year = 2023;

SELECT *
FROM italy_staging2;

CREATE TABLE italy_staging3 AS
SELECT t1.region, t1.`year`, t1.gdp, t1.agriculture, t1.industry, t1.services, t2.gdp_change, t2.agri_change, t2.ind_change, t2.serv_change
FROM italy_staging t1
LEFT JOIN italy_staging2 t2
	ON t1.region = t2.region AND t1.`year` = t2.`year`;
    
SELECT *
FROM italy_staging3;

-- Exploration

CREATE TABLE italy_staging4 AS
SELECT *, CASE
WHEN region = "Piemonte" OR region = "Valle D'Aosta" OR region = "Liguria" OR region = "Lombardia" OR region = "Trentino Alto Adige" OR region = "Provincia Autonoma Bolzano" OR region = "Provincia Autonoma Trento" OR region = "Veneto" OR region = "Friuli-Venezia Giulia" OR region = "Emilia-Romagna" OR region = "Toscana" OR region = "Umbria" OR region = "Marche" OR region = "Lazio" THEN "North"
ELSE "South"
END AS division
FROM italy_staging3;

SELECT division, `year`, 
(SUM(agriculture) / (SUM(agriculture) + SUM(industry) + SUM(services))) * 100 AS agri_perc,
(SUM(industry) / (SUM(agriculture) + SUM(industry) + SUM(services))) * 100 AS ind_perc, 
(SUM(services) / (SUM(agriculture) + SUM(industry) + SUM(services))) * 100 AS serv_change
FROM italy_staging4
GROUP BY 1,2;
 
-- Add demographics, geographic, and wine data
SELECT *
FROM italy_staging4;

SELECT *
FROM italy_demographics;

SELECT *
FROM italy_size;

SELECT *
FROM italy_wine;

SELECT *
FROM italy_staging4
WHERE region LIKE "Emilia%";

UPDATE italy_demographics
SET territory = TRIM(territory);

CREATE TABLE italy_demographics2 AS
WITH temp_table AS (
SELECT region
FROM italy_staging4)
SELECT t2.territory, t2.`year`, t2.`males`, t2.`females`, t2.`total`
FROM temp_table t1
INNER JOIN italy_demographics t2
ON t1.region = t2.territory;

SELECT *
FROM italy_demographics2;

CREATE TABLE italy_demographics3 AS
WITH non_duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY territory, `year`, males, females, total) AS row_num
FROM italy_demographics2
)
SELECT *
FROM non_duplicate_cte
WHERE row_num = 1;

SELECT *
FROM italy_demographics3;

SELECT *
FROM italy_wine;

SELECT *
FROM italy_size;

UPDATE italy_wine
SET `year` = TRIM(`year`);

UPDATE italy_demographics3
SET `year` = TRIM(`year`);

UPDATE italy_staging4
SET `year` = TRIM(`year`);

UPDATE italy_wine
SET `region` = TRIM(`region`);

UPDATE italy_size
SET `territory` = TRIM(`territory`);

UPDATE italy_staging4
SET `region` = TRIM(`region`);


CREATE TABLE italy_demographics4 AS
SELECT t1.territory, t1.`year`, t1.males, t1.females, t1.total, t2.wine
FROM italy_demographics3 t1
LEFT JOIN italy_wine t2
ON t1.territory = t2.region AND t1.`year` = t2.`year`;

SELECT region
FROM italy_staging4;

CREATE TABLE italy_size2 AS 
SELECT *
FROM italy_staging4 t1
LEFT JOIN italy_size t2
ON t1.region = t2.territory;

SELECT *
FROM italy_size2;

SELECT *
FROM italy_size2
WHERE region = "Lazio";

SELECT *
FROM italy_demographics4
WHERE territory = "Abruzzo";

CREATE TABLE italy_final AS 
SELECT t2.territory, t2.`year`, t1.gdp, t1.agriculture, t1.industry, t1.services, t1.gdp_change, t1.agri_change, t1.ind_change, t1.serv_change, t1. division, t1.`Total area (km2)`, t2.males, t2.females, t2.total, t2.wine
FROM italy_size2 t1
RIGHT JOIN italy_demographics4 t2
ON t1.region = t2.territory AND t1.`year` = t2.`year`;

SELECT *
FROM italy_final;

-- Pivot data with value added and population using union all

SELECT territory, `year`, agriculture, industry, services, males, females, total
FROM italy_final;

CREATE TABLE italy_final2 AS
SELECT territory, `year`, 'agriculture' AS category, agriculture AS Value
FROM italy_final
UNION ALL
SELECT territory, `year`, 'industry' AS category, industry AS Value
FROM italy_final
UNION ALL
SELECT territory, `year`, 'services' AS category, services AS Value
FROM italy_final
UNION ALL
SELECT territory, `year`, 'males' AS category, males AS Value
FROM italy_final
UNION ALL
SELECT territory, `year`, 'females' AS category, females AS Value
FROM italy_final
UNION ALL
SELECT territory, `year`, 'total' AS category, total AS Value
FROM italy_final;
-- region,`year`,gdp,agriculture,industry,services,gdp_change,agri_change,ind_change,serv_change,division,Total area (km2)