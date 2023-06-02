USE [BD_FIN_PES]
GO

/* reference: https://www.mssqltips.com/sqlservertip/4054/creating-a-date-dimension-or-calendar-table-in-sql-server/ */

DROP TABLE IF EXISTS DIM_TEMPO;

/* prevent set or regional settings from interfering with interpretation of dates / literals */
SET DATEFIRST 7 -- 1 = Monday, 7 = Sunday
SET DATEFORMAT mdy 
SET LANGUAGE Brazilian;

/* assume the above is here in all subsequent code blocks */

DECLARE @StartDate DATE = '20100101';

DECLARE @CutoffDate DATE = DATEADD(DAY, -1, DATEADD(YEAR, 30, @StartDate));
WITH seq(n) AS 
(
	SELECT 0 UNION ALL SELECT n + 1 FROM seq
	WHERE n < DATEDIFF(DAY, @StartDate, @CutoffDate)
), d(d) AS (
	SELECT DATEADD(DAY, n, @StartDate) FROM seq
), src AS (
	SELECT
		DAT_ANO_MES			= CONVERT(DATE, d)
		, NUM_DIA			= DATEPART(DAY, d)
		, NOM_DIA			= DATENAME(WEEKDAY, d)
		, NUM_SEM_ANO		= DATEPART(WEEK, d)
		--, TheISOWeek		= DATEPART(ISO_WEEK, d)
		, NUM_DIA_SEM		= DATEPART(WEEKDAY, d)
		, NUM_MES			= DATEPART(MONTH, d)
		, NOM_MES			= DATENAME(MONTH, d)
		, NUM_QUA			= DATEPART(Quarter, d)
		, NUM_ANO			= DATEPART(YEAR, d)
		, PRIM_DIA_MES		= DATEFROMPARTS(YEAR(d), MONTH(d), 1)
		, ULT_DIA_ANO		= DATEFROMPARTS(YEAR(d), 12, 31)
		, NUM_DIA_ANO		= DATEPART(DAYOFYEAR, d)
	FROM d
), dim AS (
	SELECT
		DAT_ANO_MES
		, NUM_DIA
		/* , TheDaySuffix = CONVERT(CHAR(2), CASE
											WHEN NUM_DIA / 10 = 1 THEN 'th'
											ELSE 
												CASE RIGHT(NUM_DIA, 1)
													WHEN '1' THEN 'st'
													WHEN '2' THEN 'nd'
													WHEN '3' THEN 'rd'
													ELSE 'th'
												END
											END)
		*/
		, NOM_DIA
		, NUM_DIA_SEM
		, NUM_DIA_SEM_MES = CONVERT(TINYINT, ROW_NUMBER() OVER (PARTITION BY PRIM_DIA_MES, NUM_DIA_SEM ORDER BY DAT_ANO_MES))
		, NUM_DIA_ANO
		, IND_DIA_FDS = CASE
						WHEN NUM_DIA_SEM IN (CASE @@DATEFIRST WHEN 1 THEN 6 WHEN 7 THEN 1 END,7) THEN 1
						ELSE 0
					END
		, NUM_SEM_ANO
		--, TheISOweek
		, PRM_DIA_SEM = DATEADD(DAY, 1 - NUM_DIA_SEM, DAT_ANO_MES)
		, ULT_DIA_SEM = DATEADD(DAY, 6, DATEADD(DAY, 1 - NUM_DIA_SEM, DAT_ANO_MES))
		, NUM_SEM_MES = CONVERT(tinyint, DENSE_RANK() OVER (PARTITION BY NUM_ANO, NUM_MES ORDER BY NUM_SEM_ANO))
		, NUM_MES
		, NOM_MES
		, PRIM_DIA_MES
		, ULT_DIA_MES = MAX(DAT_ANO_MES) OVER (PARTITION BY NUM_ANO, NUM_MES)
		, PRIM_DIA_PROX_MES = DATEADD(MONTH, 1, PRIM_DIA_MES)
		, ULT_DIA_PROX_MES = DATEADD(DAY, -1, DATEADD(MONTH, 2, PRIM_DIA_MES))
		, NUM_QUA
		, PRIM_DIA_QUA = MIN(DAT_ANO_MES) OVER (PARTITION BY NUM_ANO, NUM_QUA)
		, ULT_DIA_QUA = MAX(DAT_ANO_MES) OVER (PARTITION BY NUM_ANO, NUM_QUA)
		, NUM_ANO
		/*
		, TheISOYear = NUM_ANO - CASE
									WHEN NUM_MES = 1 AND TheISOWeek > 51 THEN 1 
									WHEN NUM_MES = 12 AND TheISOWeek = 1 THEN -1
									ELSE 0
								END
		*/
		, PRIM_DIA_ANO = DATEFROMPARTS(NUM_ANO, 1,  1)
		, ULT_DIA_ANO
		, IND_ANO_BIS = CONVERT(BIT, CASE
										WHEN (NUM_ANO % 400 = 0) OR (NUM_ANO % 4 = 0 AND NUM_ANO % 100 <> 0) THEN 1
										ELSE 0
									END)
		/* , Has53Weeks = CASE
						WHEN DATEPART(WEEK, ULT_DIA_ANO) = 53 THEN 1
						ELSE 0
					END
		*/
		/*
		, Has53ISOWeeks = CASE
							WHEN DATEPART(ISO_WEEK, ULT_DIA_ANO) = 53 THEN 1
							ELSE 0
						END
		*/
		-- , MMYYYY = CONVERT(CHAR(2), CONVERT(CHAR(8), DAT_ANO_MES, 101)) + CONVERT(CHAR(4), NUM_ANO)
		, DAT_FMT_101 = CONVERT(CHAR(10), DAT_ANO_MES, 101)
		, DAT_FMT_103 = CONVERT(CHAR(10), DAT_ANO_MES, 103)
		, DAT_FMT_112 = CONVERT(CHAR(8), DAT_ANO_MES, 112)
		, DAT_FMT_120 = CONVERT(CHAR(10), DAT_ANO_MES, 120)
		, QTD_HRS_TRB = 8
	FROM src
)
SELECT * INTO DIM_TEMPO FROM dim
ORDER BY DAT_ANO_MES
OPTION (MAXRECURSION 0);


CREATE UNIQUE CLUSTERED INDEX PK_DateDimension ON DIM_TEMPO(DAT_ANO_MES);

GO