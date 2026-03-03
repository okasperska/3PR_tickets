

-- ### Please refresh the quarter staring date 

CREATE OR REPLACE TEMP TABLE product_mopay_mart_feb_qtrly_merch_enablement_industry AS (
    WITH qtrs AS (
        SELECT
            DATE_TRUNC(quarter, cal_date) AS qtr
        FROM ap_raw_green.green.d_date AS dt
        WHERE cal_date BETWEEN '2022-10-01' AND DATE_TRUNC(quarter, CURRENT_DATE())-1
        GROUP BY 1
        ORDER BY 1
    )
    , dat AS (
        SELECT
            qtrs.qtr
            , mpm.category AS Industry
            , COUNT(DISTINCT merchant_id) AS merchant_cnt
        FROM qtrs
        INNER JOIN ap_mer_analytics.public.product_mopay_dim_mp_merchants AS mpm
            ON DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= qtrs.qtr
        WHERE 1=1
            AND mpm.first_enabled_ts IS NOT NULL
            AND mpm.ap_eligibility = TRUE
            AND mpm.square_activated_flag = 1
            AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) IS NOT NULL
            AND merchant_name != 'Stripe Pool'
            AND country_code = 'US'
            AND mpm.consumer_lending_enabled = TRUE
            AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= DATE_TRUNC(quarter, CURRENT_DATE())-1
        GROUP BY 1,2
        ORDER BY 1,2
    )
    SELECT
        qtr AS report_quarter
        , Industry
        , merchant_cnt
        , ROUND(merchant_cnt/SUM(merchant_cnt) OVER (),3) AS pct_of_merchants
    FROM dat
    ORDER BY 1,2
)
;
select * from product_mopay_mart_feb_qtrly_merch_enablement_industry where report_quarter = '2025-01-01';


CREATE OR REPLACE TEMP TABLE product_mopay_mart_feb_qtrly_merch_enablement_summary AS (
    WITH dat AS (
        SELECT
            DATE_TRUNC(quarter, mpm.first_enabled_ts::date) AS first_enabled_quarter
            , COUNT(DISTINCT merchant_id) AS merchant_cnt
            , COUNT(DISTINCT CASE WHEN mpm.consumer_lending_enabled = FALSE OR mpm.merchant_status != 'Enabled' THEN merchant_id ELSE NULL END) AS disabled_cnt
        FROM ap_mer_analytics.public.product_mopay_dim_mp_merchants AS mpm
        WHERE 1=1
            AND mpm.first_enabled_ts IS NOT NULL
            AND mpm.ap_eligibility = TRUE
            AND mpm.square_activated_flag = 1
            AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) IS NOT NULL
            AND merchant_name != 'Stripe Pool'
            AND country_code = 'US'
            AND mpm.consumer_lending_enabled = TRUE
        GROUP BY 1
        HAVING first_enabled_quarter >= '2022-10-01'
        ORDER BY 1
    )
    , pdat AS (
        SELECT
            *
            , SUM(merchant_cnt) OVER (ORDER BY first_enabled_quarter) AS rolling_sum
        FROM dat
    )
    SELECT
        first_enabled_quarter
        , rolling_sum
        , merchant_cnt
        , disabled_cnt
    FROM pdat
    WHERE 1=1
        AND first_enabled_quarter < DATE_TRUNC(quarter, CURRENT_DATE())-1
)
;
select * from product_mopay_mart_feb_qtrly_merch_enablement_summary where report_quarter = '2025-01-01' ;


CREATE OR REPLACE TEMP TABLE product_mopay_mart_feb_qtrly_merch_enablement_merchants AS (
    WITH qtrs AS (
        SELECT
            DATE_TRUNC(quarter, cal_date) AS qtr
        FROM ap_raw_green.green.d_date AS dt
        WHERE DATE_TRUNC(quarter, cal_date) BETWEEN '2022-10-01' AND DATE_TRUNC(quarter, CURRENT_DATE())-1
        GROUP BY 1
        ORDER BY 1
    )
    , dat AS (
        SELECT
            qtrs.qtr AS report_quarter
            , mpm.merchant_id
            , mpm.merchant_name
            , mpm.category
            , mpm.pcl_order_amt_usd_l12m
            , mpm.pbi_order_amt_usd_l12m
            , mpm.merch_created_date
            , ROW_NUMBER() OVER (PARTITION BY category,report_quarter ORDER BY pcl_order_amt_usd_l12m DESC NULLS LAST, pbi_order_amt_usd_l12m DESC NULLS LAST, merch_created_date) AS rnk
        FROM qtrs
        LEFT JOIN ap_mer_analytics.public.product_mopay_dim_mp_merchants AS mpm
            ON DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= qtrs.qtr
        WHERE 1=1
            AND mpm.merchant_status = 'Enabled'
            AND mpm.consumer_lending_enabled = TRUE
            AND mpm.ap_eligibility = TRUE
            AND mpm.square_activated_flag = 1
            AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= DATE_TRUNC(quarter, CURRENT_DATE())-1
        ORDER BY 4,3,2,1
    )
    SELECT
        report_quarter
        , merchant_id
        , merchant_name
        , category
    FROM dat
    WHERE rnk <= 50
    ORDER BY 4,2,3
)
;
select * from product_mopay_mart_feb_qtrly_merch_enablement_merchants   where report_quarter = '2025-01-01';
