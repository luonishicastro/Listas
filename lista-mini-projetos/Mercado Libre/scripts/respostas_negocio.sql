DECLARE @dbname nvarchar(128)
SET @dbname = N'BD_MERCADOLIBRE'

PRINT 'Please keep it the same name as defined on create_tables.sql'

DECLARE @SQL NVARCHAR(128)
SET @sql = N'USE ' + QUOTENAME(@dbname)

EXEC sp_executesql @sql
GO

/* Listar os usu�rios que fazem anivers�rio no dia de hoje e que a quantidade de vendas realizadas em Janeiro/2020 sejam superiores a 1500; */

CREATE OR ALTER VIEW VIEW_EXERCICIO_1
AS
	SELECT
		CONCAT(CST.CUSTOMER_NAME, ' ', CST.CUSTOMER_SURNAME)					AS CUSTOMER_NAME
		, SUM(ITM.ITEM_PRICE)											AS TOTAL_SALES
	FROM [dbo].[FACT_ORDER] ORD
	LEFT JOIN [dbo].FACT_ITEM ITM
		ON ITM.ITEM_ID = ORD.ITEM_ID
	LEFT JOIN [dbo].DIM_CUSTOMER CST
		ON CST.CUSTOMER_ID = ORD.CUSTOMER_ID
	WHERE YEAR([END_DATE])*100+MONTH([END_DATE])=202001 --
		AND MONTH(CAST(CST.CUSTOMER_BIRTHDAY AS DATE)) = MONTH(CAST(GETDATE() AS DATE)) AND DAY(CAST(CST.CUSTOMER_BIRTHDAY AS DATE)) = DAY(CAST(GETDATE() AS DATE))
		AND UPPER(CST.CUSTOMER_TYPE) = 'SELLER'
	GROUP BY
		CONCAT(CST.CUSTOMER_NAME, ' ', CST.CUSTOMER_SURNAME)
	HAVING SUM(ITM.ITEM_PRICE) > 1500
GO


/* Para cada m�s de 2020, solicitamos que seja exibido um top 5 dos usu�rios que mais venderam ($) na categoria Celulares. Solicitamos o m�s e ano da an�lise, nome e sobrenome do vendedor, quantidade de vendas realizadas, quantidade de produtos vendidos e o total vendido; */

CREATE OR ALTER VIEW VIEW_EXERCICIO_2
AS
	WITH CTE AS (
		SELECT
			YEAR(ITM.END_DATE)*100+MONTH(ITM.END_DATE)					AS YEAR_MONTH
			, CONCAT(CST.CUSTOMER_NAME, ' ', CST.CUSTOMER_SURNAME)		AS CUSTOMER
			, SUM(ITM.ITEM_PRICE)											AS TOTAL_SALES
			, SUM(ORD.QUANTITY)										AS QUANTITY
			, COUNT(1)												AS ORDER_QTD
			, RNK = ROW_NUMBER() OVER (PARTITION BY YEAR(ITM.END_DATE)*100+MONTH(ITM.END_DATE) ORDER BY SUM(ITM.ITEM_PRICE))
		FROM [dbo].[FACT_ORDER] ORD
		LEFT JOIN [dbo].FACT_ITEM ITM
			ON ITM.ITEM_ID = ORD.ITEM_ID
		LEFT JOIN [dbo].DIM_CATEGORY CAT
			ON CAT.CATEGORY_ID = ITM.CATEGORY_ID
		LEFT JOIN [dbo].DIM_CUSTOMER CST
			ON CST.CUSTOMER_ID = ORD.CUSTOMER_ID
		WHERE YEAR(END_DATE) = 2020
			AND CAT.CATEGORY_ID = 1
			AND UPPER(CST.CUSTOMER_TYPE) = 'SELLER'
		GROUP BY
			YEAR(ITM.END_DATE)*100+MONTH(ITM.END_DATE)
			, ORD.CUSTOMER_ID
			, CONCAT(CST.CUSTOMER_NAME, ' ', CST.CUSTOMER_SURNAME)
	) SELECT
		YEAR_MONTH
		, CUSTOMER
		, TOTAL_SALES
		, QUANTITY
		, ORDER_QTD
		, RNK = ROW_NUMBER() OVER (PARTITION BY YEAR_MONTH ORDER BY TOTAL_SALES)
	FROM CTE
	WHERE RNK <= 5
GO


/* Solicitamos popular uma nova tabela com o pre�o e estado dos itens no final do dia. Considerar que esse processo deve permitir um reprocesso. Vale ressaltar que na tabela de item, vamos ter unicamente o �ltimo estado informado pela PK definida (esse item pode ser resolvido atrav�s de uma stores procedure). */

CREATE OR ALTER PROCEDURE PROC_EXERCICIO_3
AS
BEGIN
	DROP TABLE IF EXISTS [dbo].TAB_EXERCICIO_3;

	--SELECT TOP 0 ITEM_ID, ITEM_NAME, ITEM_STATE, END_DATE, CATEGORY_ID, ITEM_PRICE INTO [dbo].TAB_EXERCICIO_3 FROM [dbo].FACT_ITEM

	CREATE TABLE [dbo].TAB_EXERCICIO_3
    (
        ITEM_ID INT
		, ITEM_NAME VARCHAR(150)
		, ITEM_STATE VARCHAR(15)
		, END_DATE DATE
		, CATEGORY_ID INT
		, ITEM_PRICE NUMERIC(8,2)
    );

	MERGE [dbo].TAB_EXERCICIO_3 AS TARGET
	USING [dbo].FACT_ITEM AS SOURCE
		ON SOURCE.ITEM_ID = TARGET.ITEM_ID
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (ITEM_ID, ITEM_NAME, ITEM_STATE, END_DATE, CATEGORY_ID, ITEM_PRICE)
		VALUES(SOURCE.ITEM_ID, SOURCE.ITEM_NAME, SOURCE.ITEM_STATE, SOURCE.END_DATE, SOURCE.CATEGORY_ID, SOURCE.ITEM_PRICE)

	WHEN MATCHED THEN UPDATE SET
		TARGET.ITEM_PRICE = SOURCE.ITEM_PRICE
		, TARGET.END_DATE = SOURCE.END_DATE;
END

EXEC [dbo].PROC_EXERCICIO_3;