---- CREATE BASE TABLE FOR 3 PARTS OF THE REPORT
CREATE OR REPLACE TABLE  PERSONAL_OKASPERSKA.public.MERCHANTS as 
(
select a.merchant_id,
a.merchant_name,
a.PRODUCT_IMPLEMENTED_DATE,
a.product_status,
a.ORDER_AMT_SUM_D365,
a.ORDER_CNT_D365,
a.CREATED_DATE,
acc.ap_industry_c industry, --can be used temporarily untill grouping is fixed by SMEs
mm2.MERCHANT_CATEGORY_CODE_INDUSTRY -- probably not right for the purpose
FROM AP_CUR_BI_G.CURATED_ANALYTICS_GREEN.MERCHANT_MASTER_PRODUCT a 
left join AP_CUR_BI_G.CURATED_ANALYTICS_GREEN.MERCHANT_MASTER_2 MM2
on a.merchant_id = mm2.merchant_id
LEFT JOIN AP_RAW_GREEN.GREEN.RAW_M_D_SALESFORCESQ_ACCOUNT  ACC
on acc.key_id = mm2.primary_account_id
where 1=1
and PRODUCT_NAME_CODE = 'CL' 
and a.PRODUCT_IMPLEMENTED_DATE is not null -- this condition makes a huge difference in coverage
and a.country_code = 'US'
);


--- SUMMARY 1
WITH summary_1_temp AS 
(
        SELECT
            DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) AS first_enabled_quarter
            , COUNT(DISTINCT merchant_id) AS merchant_cnt
           -- , COUNT(DISTINCT CASE WHEN mpm.consumer_lending_enabled = FALSE OR mpm.merchant_status != 'Enabled' THEN merchant_id ELSE NULL END) AS disabled_cnt -- the dispabled count here is urely from legacy code, at this stage not sure how it should look like
        FROM PERSONAL_OKASPERSKA.public.MERCHANTS base
        GROUP BY 1
        HAVING first_enabled_quarter >= '2022-10-01'
        ORDER BY 1
    )
    , summary_1 AS (
        SELECT
            *
            , SUM(merchant_cnt) OVER (ORDER BY first_enabled_quarter) AS rolling_sum
        FROM summary_1_temp
    )
    SELECT
        first_enabled_quarter
        , rolling_sum
        , merchant_cnt
       -- , disabled_cnt
    FROM summary_1
    WHERE 1=1
        AND first_enabled_quarter = DATE_TRUNC(quarter, CURRENT_DATE())-1


--- SUMMARY 2
WITH qtrs AS (
        SELECT
            DATE_TRUNC(quarter, cal_date) AS qtr
        FROM ap_raw_green.green.d_date AS dt
        WHERE cal_date BETWEEN '2022-10-01' AND DATE_TRUNC(quarter, CURRENT_DATE())-1
        GROUP BY 1
        ORDER BY 1
    ) 
, summary_2 AS 
 (
        SELECT
            qtrs.qtr AS report_quarter
            , base.industry AS Industry
            , COUNT(DISTINCT merchant_id) AS merchant_cnt
        FROM qtrs
        INNER JOIN PERSONAL_OKASPERSKA.public.MERCHANTS base
            ON DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) <= qtrs.qtr
        WHERE 1=1
            AND DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) IS NOT NULL
            AND DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) <= DATE_TRUNC(quarter, CURRENT_DATE())-1
        GROUP BY 1,2
        ORDER BY 1,2
    )

SELECT
report_quarter
, Industry
, merchant_cnt
, ROUND(merchant_cnt/SUM(merchant_cnt) OVER (),3) AS pct_of_merchants
FROM  summary_2
where report_quarter = DATE_TRUNC(quarter, CURRENT_DATE())-1
ORDER BY 1,2


--- SUMMARY 3
 WITH qtrs AS (
        SELECT
            DATE_TRUNC(quarter, cal_date) AS qtr
        FROM ap_raw_green.green.d_date AS dt
        WHERE DATE_TRUNC(quarter, cal_date) BETWEEN '2022-10-01' AND DATE_TRUNC(quarter, CURRENT_DATE())-1
        GROUP BY 1
        ORDER BY 1
    )
    , summary_3 AS (
        SELECT
            qtrs.qtr AS report_quarter
            , base.merchant_id
            , base.merchant_name
            , base.industry
            , ROW_NUMBER() OVER (PARTITION BY industry, report_quarter ORDER BY ORDER_AMT_SUM_D365 DESC NULLS LAST, ORDER_CNT_D365 DESC NULLS LAST, created_date) AS rnk
        FROM qtrs
        LEFT JOIN PERSONAL_OKASPERSKA.public.MERCHANTS base
            ON DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) <= qtrs.qtr
        WHERE 1=1
            AND DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) IS NOT NULL
            AND DATE_TRUNC(quarter, base.PRODUCT_IMPLEMENTED_DATE::date) <= DATE_TRUNC(quarter, CURRENT_DATE())-1
    
        ORDER BY 4,3,2,1
    )
    SELECT
    report_quarter
        , merchant_id
        , merchant_name
        , industry
    FROM summary_3
    WHERE rnk <= 50
    and report_quarter = DATE_TRUNC(quarter, CURRENT_DATE())-1
    ORDER BY 4,2,3
;


