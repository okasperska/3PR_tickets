--NOTES
--Author: Jeffery Li (jeffery@)
--Why is so much of this code commented out? I inherited most of this code from a previous PDS, however, much of the old pipeline could not be verified. The previous code was undocumented, we had to retrieve all of it from snowflake query history. The majority of commented out sections represent fields that are not actually consumed by the end users (there are a handful of comments for other reasons explicitly stated), so they have been removed from the final outputs to simplify the code and improve its integrity. The commented out sections are preserved as historical artifact.

-- I created backups of the old tables here:
-- create table app_cash_beta.jeffery.product_mopay_dim_mp_merchants_backup as (
-- select * from ap_mer_analytics.public.product_mopay_dim_mp_merchants)

-- create table app_cash_beta.jeffery.product_mopay_mart_feb_qtrly_merch_enablement_industry_backup as (
-- select * from ap_mer_analytics.public.product_mopay_mart_feb_qtrly_merch_enablement_industry)

-- create table app_cash_beta.jeffery.product_mopay_mart_feb_qtrly_merch_enablement_summary_backup as (
-- select * from ap_mer_analytics.public.product_mopay_mart_feb_qtrly_merch_enablement_summary)

-- create table app_cash_beta.jeffery.product_mopay_mart_feb_qtrly_merch_enablement_merchants_backup as (
-- select * from ap_mer_analytics.public.product_mopay_mart_feb_qtrly_merch_enablement_merchants)


CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_square_fpt_temp AS (
    SELECT
        fpt.payment_token,
        fpt.is_card_present,
        fpt.product_name,
        fpt.amount_base_unit_usd,
        fpt.square_issued_card,
        fpt.card_brand,
        fpt.unit_token,
        fpt.payment_trx_recognized_at,
        fpt.payment_trx_recognized_date,
        fpt.is_gpv,
        fpt.country_code
    FROM
        APP_BI.hexagon.vFACT_PAYMENT_TRANSACTIONS AS fpt
    WHERE
        1 = 1
        AND fpt.IS_GPV = 1
        AND fpt.PAYMENT_TRX_RECOGNIZED_DATE BETWEEN '2023-01-01'::date
        AND CURRENT_DATE
        AND fpt.product_name IN (
            'Invoices',
            'Square Online Store',
            'Square Online Checkout',
            'eCommerce API',
            'Appointments'
        ) --, 'Virtual Terminal', 'Terminal API')
        AND fpt.country_code = 'US'
);







CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_square_merchant_types AS (
    WITH dist_merch AS (
        SELECT
            m.merchant_token,
            m.merchant_active_status,
            m.merchant_receipt_country_code,
            m.merchant_business_category,
            CASE
                WHEN COALESCE(m.num_currently_active_units, 0) > 0 THEN 1
                ELSE 0
            END AS merchant_active_flag
        FROM
            APP_BI.hexagon.vDIM_USER AS m
        GROUP BY
            1,
            2,
            3,
            4,
            5
        HAVING
            merchant_active_flag = 1
    ),
    enroll_st AS (
        SELECT
            m.merchant_token,
            m.merchant_active_flag,
            m.merchant_receipt_country_code,
            m.merchant_business_category,
            CASE
                WHEN es.merchant_token IS NULL THEN 0
                ELSE 1
            END AS enroll_rec_exists,
            es.afterpay_merchant_id,
            es.eligibility_status AS eligibility_status,
            es.enrollment_status AS enrollment_status,
            ROW_NUMBER() OVER (
                PARTITION BY m.merchant_token
                ORDER BY
                    es.updated_at ASC,
                    m.merchant_token ASC
            ) AS rnk
        FROM
            dist_merch AS m
            LEFT JOIN PAYTYPE_ENROLLER.RAW_OLTP.afterpay_enrollments AS es ON m.merchant_token = es.merchant_token
    )
    SELECT
        du.merchant_token,
        -- , du.merchant_created_at
        -- , du.merchant_business_type
        -- , du.merchant_business_category
        TRY_CAST(apdm.id AS INT) AS ap_merchant_id, 
        -- , es.merchant_active_flag
        es.merchant_receipt_country_code AS country_code,
        es.enroll_rec_exists,
        es.eligibility_status,
        es.enrollment_status,
        -- , fpt.product_name
        -- , apdm.merchant_category_code
        -- , MAX(mccls.description) AS mcc_description
        -- , MAX(mccls.MOR_CATEGORY_EXCLUDES_EU_ = 'Approved')::int AS HAS_APPROVED_MCC
        -- , MAX(mccls.MOR_CATEGORY_EXCLUDES_EU_ = 'Not Eligible')::int AS HAS_NOT_ELIGIBLE_MCC
        -- , MAX(mccls.MOR_CATEGORY_EXCLUDES_EU_ = 'Restricted')::int AS HAS_RESTRICTED_MCC
        -- , MAX(mccls.MOR_CATEGORY_EXCLUDES_EU_ = 'Prohibited')::int AS HAS_PROHIBITED_MCC
        -- , MIN(mccls.MOR_CATEGORY_EXCLUDES_EU_ = 'Approved')::int AS HAS_ALL_APPROVED_MCC -- needed for online elig
        -- , MIN(DATE_TRUNC('day', PAYMENT_TRX_RECOGNIZED_AT)) AS first_txn_dt
        -- , MAX(DATE_TRUNC('day', PAYMENT_TRX_RECOGNIZED_AT)) AS last_txn_dt
        -- , MAX(CURRENT_DATE()) AS data_proc_date
        -- , COUNT(DISTINCT CASE WHEN fpt.IS_CARD_PRESENT = 0 THEN payment_token ELSE NULL END) AS ONLINE_PMTS
        -- , COUNT(DISTINCT CASE WHEN fpt.IS_CARD_PRESENT = 1 THEN payment_token ELSE NULL END) AS INSTORE_PMTS
        -- , COUNT(DISTINCT CASE WHEN fpt.IS_CARD_PRESENT = 0 AND NVL(fpt.amount_base_unit_usd,0)/100 >= 400 THEN payment_token ELSE NULL END) AS ONLINE_PMTS_400plus
        -- , COUNT(DISTINCT CASE WHEN fpt.IS_CARD_PRESENT = 1 AND NVL(fpt.amount_base_unit_usd,0)/100 >= 400 THEN payment_token ELSE NULL END) AS INSTORE_PMTS_400plus
        -- , COUNT(DISTINCT CASE WHEN fpt.IS_CARD_PRESENT = 0 AND NVL(fpt.amount_base_unit_usd,0)/100 >= 200 THEN payment_token ELSE NULL END) AS ONLINE_PMTS_200plus
        -- , COUNT(DISTINCT CASE WHEN fpt.IS_CARD_PRESENT = 1 AND NVL(fpt.amount_base_unit_usd,0)/100 >= 200 THEN payment_token ELSE NULL END) AS INSTORE_PMTS_200plus
        SUM(
            CASE
                WHEN fpt.IS_CARD_PRESENT = 0 THEN NVL(fpt.AMOUNT_BASE_UNIT_USD, 0) / 100
            END
        ) AS ONLINE_GPV_USD -- , SUM(CASE WHEN fpt.IS_CARD_PRESENT = 1 THEN NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 END) AS INSTORE_GPV_USD
        -- , SUM(CASE WHEN fpt.IS_CARD_PRESENT = 1 AND NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 >= 400 THEN NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 END) AS INSTORE_GPV_USD_400plus
        -- , SUM(CASE WHEN fpt.IS_CARD_PRESENT = 0 AND NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 >= 400 THEN NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 END) AS ONLINE_GPV_USD_400plus
        -- , SUM(CASE WHEN fpt.IS_CARD_PRESENT = 1 AND NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 >= 200 THEN NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 END) AS INSTORE_GPV_USD_200plus
        -- , SUM(CASE WHEN fpt.IS_CARD_PRESENT = 0 AND NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 >= 200 THEN NVL(fpt.AMOUNT_BASE_UNIT_USD,0)/100 END) AS ONLINE_GPV_USD_200plus
        -- , NVL(SUM(case when fpt.square_issued_card = 'AFTERPAY_CARD' THEN 1 ELSE 0 END),0)                              AS AP_INSTORE_ORDER_COUNT_TOTAL
        -- , NVL(SUM(case when fpt.square_issued_card = 'AFTERPAY_CARD' THEN fpt.AMOUNT_BASE_UNIT_USD / 100 ELSE 0 END),0) AS AP_INSTORE_GPV_USD_TOTAL
        -- , NVL(SUM(case when fpt.card_brand = 'AFTERPAY' THEN 1 ELSE 0 END),0)                                           AS AP_ONLINE_ORDER_COUNT_TOTAL
        -- , NVL(SUM(case when fpt.card_brand = 'AFTERPAY' THEN fpt.AMOUNT_BASE_UNIT_USD / 100 ELSE 0 END),0)              AS AP_ONLINE_GPV_USD_TOTAL
    FROM
        ap_mer_analytics.public.product_mopay_square_fpt_temp AS fpt 
        --FROM APP_BI.hexagon.vFACT_PAYMENT_TRANSACTIONS AS fpt
        /*
            LEFT JOIN APP_BI.hexagon.vDIM_USER AS du
                ON fpt.UNIT_TOKEN = du.USER_TOKEN
            */
        INNER JOIN APP_BI.hexagon.vDIM_USER AS du ON fpt.unit_token = du.best_available_unit_token
        AND fpt.IS_GPV = 1
        /*
                AND du.IS_CURRENTLY_DEACTIVATED = 0
                AND du.IS_CURRENTLY_FROZEN = 0
                AND du.UNIT_ACTIVE_STATUS = 1
                AND du.IS_CURRENTLY_PERMITTED_TO_ACCEPT_CARD_PAYMENTS = 1
                AND du.num_currently_active_units > 0
                AND du.unit_active_status = TRUE
                */
        AND fpt.PAYMENT_TRX_RECOGNIZED_DATE BETWEEN --dateadd('month',-6,date_trunc('week',current_date())) and date_trunc('week',current_date())-1
        --dateadd('month',-12,date_trunc('week',current_date())) and date_trunc('week',current_date())-1
        --dateadd('month',-12,date_trunc('week','2022-09-28'::date)) and date_trunc('week','2022-09-28'::date)-1
        '2023-01-01'::date
        AND CURRENT_DATE
        AND fpt.product_name IN (
            'Invoices',
            'Square Online Store',
            'Square Online Checkout',
            'eCommerce API',
            'Appointments'
        ) 
        --, 'Virtual Terminal', 'Terminal API')
        AND fpt.country_code = 'US'
        LEFT JOIN AP_RAW_GREEN.GREEN.D_MERCHANT AS apdm ON du.merchant_token = apdm.agency_merchant_reference -- LEFT JOIN FIVETRAN.APP_PAYMENTS.AFTERPAY_MCC_LIST AS mccls
        --     ON mccls.MCC = TRY_CAST(apdm.merchant_category_code AS INT)
        LEFT JOIN enroll_st AS es ON es.MERCHANT_TOKEN = du.MERCHANT_TOKEN
        AND rnk = 1
    WHERE
        1 = 1 
    -- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
    GROUP BY
        1,
        2,
        3,
        4,
        5,
        6
);








CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_dim_mp_enabled_merchants AS (
    WITH square_merch AS (
        SELECT
            ap_merchant_id,
            MAX(
                CASE
                    WHEN sq.country_code = 'US'
                    AND sq.enroll_rec_exists = 1
                    AND sq.eligibility_status = 'ELIGIBLE'
                    AND sq.enrollment_status NOT IN (
                        'OPTED_OUT',
                        'FAILED',
                        'OFFBOARDED',
                        'DELETED'
                    ) THEN 1
                    ELSE 0
                END
            ) AS ap_eligibility,  
            -- , MAX(
            --     CASE
            --     --WHEN product_name IN ('Square Online Checkout', 'Square Online Store') THEN 1
            --     WHEN product_name IN ('Invoices') THEN 2
            --     ELSE 0 END
            --     ) AS square_type
            SUM(sq.online_gpv_usd) AS gmv_sq_online_gmv 
            -- , SUM(CASE WHEN product_name = 'Invoices' THEN ONLINE_GPV_USD_400plus ELSE 0 END)     AS gmv_orders_400plus_invoices
            -- , SUM(ONLINE_GPV_USD_400plus)                                                         AS gmv_orders_400plus
            -- , gmv_orders_400plus-gmv_orders_400plus_invoices                                      AS gmv_orders_400_plus_noninovices
            -- , SUM(ONLINE_GPV_USD - ONLINE_GPV_USD_400plus)                                        AS gmv_orders_less_than_400
        FROM
            ap_mer_analytics.public.product_mopay_square_merchant_types AS sq 
            -- LEFT JOIN ap_cur_bi_g.curated_analytics_green.cur_m_m_merchant_master AS mm
            --     ON sq.ap_merchant_id = mm.merchant_id
        WHERE
            sq.ap_merchant_id IS NOT NULL
        GROUP BY
            1
    ) -- , merch_partners AS (
    --     SELECT
    --         op.merchant_id
    --         , MIN(
    --             CASE
    --             WHEN op.shop_directory_name = 'AFTERPAY_BUTTON' THEN 1
    --             WHEN op.order_transaction_source = 'SQ_ONLINE' AND sm.square_type = 2 THEN 2
    --             WHEN op.order_transaction_source = 'SQ_ONLINE' THEN 3
    --             WHEN op.order_transaction_source = 'STRIPE' THEN 4
    --             WHEN (
    --                 op.partner_id IN ('Adyen C-level', 'Adyen M-Level')
    --                 OR op.order_transaction_source = 'ADYEN'
    --                 )
    --                 THEN 5
    --             WHEN (
    --                 LOWER(op.order_transaction_source) LIKE '%shopify%'
    --                 OR LOWER(op.partner_id) LIKE '%shopify%'
    --                 )
    --                 THEN 6
    --             WHEN op.partner_id = 'Wix'
    --                 THEN 7
    --             WHEN (
    --                 op.order_transaction_source IN ('API_V0', 'API_V1', 'API_V2')
    --                 AND op.partner_id NOT IN ('Custom .NET', 'Custom Java', 'Custom Ruby', 'API_V1 | Online Partner', 'API_V0 | Online Unknown Partner ID', 'API_V1 | Online Unknown Partner ID', 'API_V2 | Online Partner', 'API_V2 | Online Unknown Partner ID')
    --                 )
    --                 THEN 8
    --             WHEN (
    --                 op.order_transaction_source IN ('API_V0', 'API_V1', 'API_V2')
    --                 AND (
    --                     op.partner_id IN ('Custom .NET', 'Custom Java', 'Custom Ruby')
    --                     OR op.partner_id IN ('API_V1 | Online Partner', 'API_V0 | Online Unknown Partner ID', 'API_V1 | Online Unknown Partner ID', 'API_V2 | Online Partner', 'API_V2 | Online Unknown Partner ID')
    --                     OR op.partner_id IS NULL
    --                     )
    --                 )
    --                 THEN 9
    --             WHEN op.order_transaction_source = 'SINGLE_USE_CARD' THEN 10
    --             WHEN op.order_transaction_source = 'CYBERSOURCE' THEN 11
    --             ELSE 100
    --             END
    --             ) AS merchant_integration_type_id
    --     FROM AP_MER_ANALYTICS.PUBLIC.product_mopay_dim_merchant_last_order AS op
    --     LEFT JOIN square_merch AS sm ON op.merchant_id = sm.ap_merchant_id
    --     WHERE op.merchant_id IS NOT NULL
    --         --AND op.order_rnk = 1
    --     GROUP BY 1
    -- )
    -- , merch_partners2 AS (
    --     SELECT
    --         am.merchant_id
    --         , CASE
    --             WHEN merchant_integration_type_id = 1 THEN 'Button-Button'
    --             WHEN merchant_integration_type_id = 2 THEN 'Agency-Square-Invoices'
    --             WHEN merchant_integration_type_id = 3 THEN 'Agency-Square-Online'
    --             WHEN merchant_integration_type_id = 4 THEN 'Agency-Stripe'
    --             WHEN merchant_integration_type_id = 5 THEN 'Agency-Adyen'
    --             WHEN merchant_integration_type_id = 6 THEN 'Ecomm-Shopify'
    --             WHEN merchant_integration_type_id = 7 THEN 'Ecomm-Wix'
    --             WHEN merchant_integration_type_id = 8 THEN 'Ecomm-Other'
    --             WHEN merchant_integration_type_id = 9 THEN 'Direct-API'
    --             WHEN merchant_integration_type_id = 10 THEN 'Other-SUP'
    --             WHEN merchant_integration_type_id = 11 THEN 'Other-Cybersource'
    --             ELSE 'Other'
    --             END AS merchant_integration_type
    --     FROM merch_partners AS am
    -- )
    -- , fee_config AS (
    --     SELECT
    --         merchant_id
    --         , fee_type_id
    --         , fixed_amount
    --         , variable_rate
    --         , effective_from_datetime
    --         , is_enabled
    --         , ROW_NUMBER() OVER (PARTITION BY merchant_id, fee_type_id ORDER BY effective_from_datetime DESC) AS rnk
    --     FROM ap_raw_green.green.f_merchant_fee_configuration AS fc
    --     WHERE 1=1
    --         AND fc.is_enabled = TRUE
    --         --AND fixed_amount != 0 -- Commented out because it is possible to have 0 fee MP fees
    --         AND channel_type_id = 1 -- Online Channel
    -- )
,
    first_enabled AS (
        SELECT
            merchant_id,
            fee_type_id,
            fixed_amount,
            variable_rate,
            effective_from_datetime,
            is_enabled,
            ROW_NUMBER() OVER (
                PARTITION BY merchant_id,
                fee_type_id
                ORDER BY
                    effective_from_datetime ASC
            ) AS rnk
        FROM
            ap_raw_green.green.f_merchant_fee_configuration AS fc
        WHERE
            1 = 1 
            --AND fixed_amount != 0 -- Commented out because it is possible to have 0 fee MP fees
            AND channel_type_id = 1 -- Online Channel
    )
    SELECT
        mm.merchant_id,
        mm.merchant_name, 
        -- , COALESCE(mp.merchant_integration_type,
        --     CASE
        --     WHEN square_type = 2 THEN 'Agency-Square-Invoices'
        --     WHEN square_type = 0 THEN 'Agency-Square-Online'
        --     WHEN mm.agency_ref = 'SQUARE' THEN 'Agency-Square-Online'
        --     WHEN mm.agency_ref = 'STRIPE' THEN 'Agency-Stripe'
        --     WHEN mm.agency_ref = 'ADYEN'  THEN 'Agency-Adyen'
        --     ELSE 'No Orders' END
        --     ) AS merchant_integration_type
        COALESCE(sm.ap_eligibility, 1) AS ap_eligibility,
        -- , mlo.order_transaction_source
        -- , mlo.shop_directory_name
        -- , mlo.partner_id
        -- , mlo.order_datetime AS last_order_datetime
        fe.effective_from_datetime AS first_enabled_ts, 
        -- , fc.fixed_amount
        -- , fc.variable_rate
        COALESCE(chan.consumer_lending_enabled, FALSE) AS consumer_lending_enabled,
        SUM(gmv_sq_online_gmv) AS square_online_gmv,
        -- , COUNT(DISTINCT CASE WHEN om.payment_type = 'PCL' THEN om.order_id ELSE NULL END)                                AS pcl_order_cnt_l12m
        SUM(
            CASE
                WHEN om.payment_type = 'PCL' THEN om.order_amount_usd
                ELSE 0
            END
        ) AS pcl_order_amt_usd_l12m, 
        -- , COUNT(DISTINCT CASE WHEN om.payment_type = 'PBI' THEN om.order_id ELSE NULL END)                                AS pbi_order_cnt_l12m
        -- , COUNT(DISTINCT CASE WHEN om.payment_type = 'PBI' AND om.order_amount_usd >= 200 THEN om.order_id ELSE NULL END) AS pbi200_order_cnt_l12m
        -- , COUNT(DISTINCT CASE WHEN om.payment_type = 'PBI' AND om.order_amount_usd >= 400 THEN om.order_id ELSE NULL END) AS pbi400_order_cnt_l12m
        SUM(
            CASE
                WHEN om.payment_type = 'PBI' THEN om.order_amount_usd
                ELSE 0
            END
        ) AS pbi_order_amt_usd_l12m, 
        -- , SUM(CASE WHEN om.payment_type = 'PBI' AND om.order_amount_usd >= 200 THEN om.order_amount_usd ELSE 0 END)       AS pbi200_order_amt_usd_l12m
        -- , SUM(CASE WHEN om.payment_type = 'PBI' AND om.order_amount_usd >= 400 THEN om.order_amount_usd ELSE 0 END)       AS pbi400_order_amt_usd_l12m
        -- , AVG(CASE WHEN om.payment_type = 'PBI' THEN om.order_amount_usd ELSE NULL END)                                   AS avg_pbi_order_amt_l12m
        -- , AVG(CASE WHEN om.payment_type = 'PBI' AND om.order_amount_usd >= 200 THEN om.order_amount_usd ELSE NULL END)    AS avg_pbi200_order_amt_l12m
        -- , AVG(CASE WHEN om.payment_type = 'PBI' AND om.order_amount_usd >= 400 THEN om.order_amount_usd ELSE NULL END)    AS avg_pbi400_order_amt_l12m
        CURRENT_TIMESTAMP AS updated_ts
    FROM
        ap_cur_bi_g.curated_analytics_green.cur_m_m_merchant_master AS mm 
        -- LEFT JOIN merch_partners2 AS mp
        --     ON mm.merchant_id = mp.merchant_id
        LEFT JOIN square_merch AS sm ON mm.merchant_id = sm.ap_merchant_id
        LEFT JOIN ap_raw_green.green.raw_m_d_aurora_paylater_merchant_channel AS chan ON chan.merchant_id = mm.merchant_id
        AND chan.channel_type_id = 1 --Online Only Filter
        -- LEFT JOIN AP_MER_ANALYTICS.PUBLIC.product_mopay_dim_merchant_last_order AS mlo
        --     ON mm.merchant_id = mlo.merchant_id
        LEFT JOIN ap_cur_bi_g.curated_analytics_green.cur_c_m_order_master AS om ON mm.merchant_id = om.merchant_id
        AND om.order_date >= CURRENT_DATE -365 
        -- LEFT JOIN fee_config AS fc
        --     ON mm.merchant_id = fc.merchant_id
        --     AND fc.is_enabled = TRUE
        --     AND fc.rnk = 1
        --     AND fc.fee_type_id = 4
        LEFT JOIN first_enabled AS fe ON mm.merchant_id = fe.merchant_id
        AND fe.rnk = 1
        AND fe.fee_type_id = 4
    WHERE
        1 = 1 
        --AND consumer_lending_enabled = TRUE
        --GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
    GROUP BY
        1,
        2,
        3,
        4,
        5
);








CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_dim_mp_merchants AS (
    -- WITH merch_dts AS (
    --     SELECT
    --         o.merchant_id
    --         , MIN(CASE WHEN o.payment_type = 'PCL' THEN o.order_date ELSE NULL END) AS first_PCL_ord_dt
    --         , MIN(CASE WHEN o.payment_type = 'PBI' THEN o.order_date ELSE NULL END) AS first_BNPL_ord_dt
    --     FROM AP_CUR_BI_G.CURATED_ANALYTICS_GREEN.cur_c_m_order_master AS o
    --     GROUP BY 1
    -- )
    -- , vertical_mapping AS (
    --     SELECT
    --         vm.mcc
    --         , vm.mapped_vertical
    --         , vm.mcp_category
    --     FROM ap_mer_analytics.public.product_mopay_dim_merchant_vertical_mapping AS vm ################################################################################# JL: I don't believe we trust this table anymore
    --     WHERE mcc IS NOT NULL
    -- )
    -- , mgd AS (
    --     SELECT
    --         merchant_id
    --     FROM ap_mer_analytics.public.product_mopay_fact_managed_merchants ################################################################################# JL: I don't believe we trust this table anymore
    --     GROUP BY 1
    -- )
    SELECT
        m.merchant_id,
        m.merchant_name,
        m.category,
        -- , m.merchant_category_code AS mcc
        -- , m.merchant_category_code_name AS mcc_name
        -- , m.merchant_category_code_industry AS mcc_industry
        -- , COALESCE(m.merchant_ownership,'SMB') AS merch_ownership
        -- , CASE WHEN COALESCE(m.merchant_ownership, 'SMB') = 'SMB' THEN COALESCE(m.sub_tier, 'SMB_Small') ELSE m.merchant_ownership END AS merch_sub_segment
        m.created_date AS merch_created_date,
        -- , COALESCE(m.store_cnt,0) AS store_cnt
        m.merchant_status, 
        m.country_code,
        -- , m.online_enabled_flag
        -- , m.instore_enabled_flag
        -- , m.agency_ref
        -- , CASE WHEN m.order_cnt > 0 THEN 1 ELSE 0 END AS merchant_activated_flag
        -- , COALESCE(vm.mapped_vertical, m.merchant_category_code_name) AS vertical_name
        -- , dt.first_PCL_ord_dt
        -- , dt.first_BNPL_ord_dt
        -- , COALESCE(mp.merchant_integration_type, 'No Orders') AS merchant_integration_type
        -- , mp.order_transaction_source AS last_online_order_transaction_source
        -- , mp.shop_directory_name AS last_online_order_shop_directory_name
        -- , mp.partner_id AS last_online_order_partner_id
        mp.ap_eligibility,
        mp.first_enabled_ts,
        -- , mp.fixed_amount
        -- , mp.variable_rate
        CASE
            WHEN COALESCE(mp.square_online_gmv, 1) > 0 THEN 1
            ELSE 0
        END AS square_activated_flag, --Default 1 for AP only merchants
        -- , ROUND(mp.pcl_order_cnt_l12m , 2) AS pcl_order_cnt_l12m
        ROUND(mp.pcl_order_amt_usd_l12m, 2) AS pcl_order_amt_usd_l12m,
        -- , ROUND(mp.pbi_order_cnt_l12m, 2) AS pbi_order_cnt_l12m
        -- , ROUND(mp.pbi200_order_cnt_l12m, 2) AS pbi200_order_cnt_l12m
        -- , ROUND(mp.pbi400_order_cnt_l12m, 2) AS pbi400_order_cnt_l12m
        ROUND(mp.pbi_order_amt_usd_l12m, 2) AS pbi_order_amt_usd_l12m,
        -- , ROUND(mp.pbi200_order_amt_usd_l12m, 2) AS pbi200_order_amt_usd_l12m
        -- , ROUND(mp.pbi400_order_amt_usd_l12m, 2) AS pbi400_order_amt_usd_l12m
        -- , ROUND(mp.avg_pbi_order_amt_l12m, 2) AS avg_pbi_order_amt_l12m
        -- , ROUND(mp.avg_pbi200_order_amt_l12m, 2) AS avg_pbi200_order_amt_l12m
        -- , ROUND(mp.avg_pbi400_order_amt_l12m, 2) AS avg_pbi400_order_amt_l12m
        -- , CASE WHEN mgd.merchant_id IS NOT NULL THEN 'Managed' ELSE 'Unmanaged' END AS managed_flag
        -- , CURRENT_TIMESTAMP() AS updated_ts
        mp.consumer_lending_enabled
    FROM
        AP_CUR_BI_G.CURATED_ANALYTICS_GREEN.cur_m_m_merchant_master AS m
        LEFT JOIN ap_mer_analytics.public.product_mopay_dim_mp_enabled_merchants AS mp ON m.merchant_id = mp.merchant_id 
        -- LEFT JOIN merch_dts AS dt
        --     ON m.merchant_id = dt.merchant_id
        -- LEFT JOIN vertical_mapping AS vm
        --     ON m.merchant_category_code = vm.mcc
        -- LEFT JOIN mgd
        --     ON m.merchant_id = mgd.merchant_id
    WHERE
        1 = 1 
        --AND m.country_code = 'US'
        --AND m.online_enabled_flag = TRUE
        --AND m.instore_enabled_flag = FALSE
        --AND m.merchant_status = 'Enabled'
);









CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_mart_feb_qtrly_merch_enablement_industry AS (
    WITH qtrs AS (
        SELECT
            DATE_TRUNC(quarter, cal_date) AS qtr
        FROM
            ap_raw_green.green.d_date AS dt
        WHERE
            DATE_TRUNC(quarter, cal_date) BETWEEN '2022-10-01'
            AND DATE_TRUNC(quarter, CURRENT_DATE()) -1
        GROUP BY
            1
        ORDER BY
            1
    ),
    dat AS (
        SELECT
            qtrs.qtr,
            mpm.category AS Industry,
            COUNT(DISTINCT merchant_id) AS merchant_cnt
        FROM
            qtrs
            INNER JOIN ap_mer_analytics.public.product_mopay_dim_mp_merchants AS mpm ON DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= qtrs.qtr
        WHERE
            1 = 1
            AND mpm.first_enabled_ts IS NOT NULL
            AND mpm.ap_eligibility = TRUE
            AND mpm.square_activated_flag = 1
            AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) IS NOT NULL
            AND merchant_name != 'Stripe Pool'
            AND country_code = 'US'
            AND mpm.consumer_lending_enabled = TRUE 
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) = '2022-10-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-01-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-04-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-07-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-10-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-10-01'
        GROUP BY
            1,
            2
        ORDER BY
            1,
            2
    )
    SELECT
        qtr AS report_quarter,
        Industry,
        merchant_cnt,
        ROUND(merchant_cnt / SUM(merchant_cnt) OVER (), 3) AS pct_of_merchants
    FROM
        dat
    ORDER BY
        1,
        2
);










------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_mart_feb_qtrly_merch_enablement_summary AS (
    WITH dat AS (
        SELECT
            DATE_TRUNC(quarter, mpm.first_enabled_ts::date) AS first_enabled_quarter,
            COUNT(DISTINCT merchant_id) AS merchant_cnt,
            COUNT(
                DISTINCT CASE
                    WHEN mpm.consumer_lending_enabled = FALSE
                    OR mpm.merchant_status != 'Enabled' THEN merchant_id
                    ELSE NULL
                END
            ) AS disabled_cnt
        FROM
            ap_mer_analytics.public.product_mopay_dim_mp_merchants AS mpm
        WHERE
            1 = 1
            AND mpm.first_enabled_ts IS NOT NULL
            AND mpm.ap_eligibility = TRUE
            AND mpm.square_activated_flag = 1
            AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) IS NOT NULL
            AND merchant_name != 'Stripe Pool'
            AND country_code = 'US'
            AND mpm.consumer_lending_enabled = TRUE
        GROUP BY
            1
        HAVING
            first_enabled_quarter >= '2022-10-01'
        ORDER BY
            1
    ),
    pdat AS (
        SELECT
            *,
            SUM(merchant_cnt) OVER (
                ORDER BY
                    first_enabled_quarter
            ) AS rolling_sum
        FROM
            dat
    )
    SELECT
        first_enabled_quarter AS report_quarter,
        rolling_sum,
        merchant_cnt,
        disabled_cnt
    FROM
        pdat
    WHERE
        1 = 1 
        --AND first_enabled_quarter = '2022-10-01'
        --AND first_enabled_quarter = '2023-01-01'
        --AND first_enabled_quarter = '2023-04-01'
        --AND first_enabled_quarter = '2023-07-01'
        --AND first_enabled_quarter = '2023-10-01'
        --AND first_enabled_quarter < DATE_TRUNC(quarter, current_date())
);











-------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE ap_mer_analytics.public.product_mopay_mart_feb_qtrly_merch_enablement_merchants AS (
    WITH qtrs AS (
        SELECT
            DATE_TRUNC(quarter, cal_date) AS qtr
        FROM
            ap_raw_green.green.d_date AS dt
        WHERE
            DATE_TRUNC(quarter, cal_date) BETWEEN '2022-10-01'
            AND DATE_TRUNC(quarter, CURRENT_DATE()) -1
        GROUP BY
            1
        ORDER BY
            1
    ),
    dat AS (
        SELECT
            qtrs.qtr AS report_quarter,
            mpm.merchant_id,
            mpm.merchant_name,
            mpm.category,
            mpm.pcl_order_amt_usd_l12m,
            mpm.pbi_order_amt_usd_l12m,
            mpm.merch_created_date,
            ROW_NUMBER() OVER (
                PARTITION BY category,
                report_quarter
                ORDER BY
                    pcl_order_amt_usd_l12m DESC NULLS LAST,
                    pbi_order_amt_usd_l12m DESC NULLS LAST,
                    merch_created_date
            ) AS rnk
        FROM
            qtrs
            LEFT JOIN ap_mer_analytics.public.product_mopay_dim_mp_merchants AS mpm ON DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= qtrs.qtr
        WHERE
            1 = 1
            AND mpm.merchant_status = 'Enabled'
            AND mpm.consumer_lending_enabled = TRUE
            AND mpm.ap_eligibility = TRUE
            AND mpm.square_activated_flag = 1 
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) = '2022-10-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-01-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-04-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-07-01'
            --AND DATE_TRUNC(quarter, mpm.first_enabled_ts::date) <= '2023-10-01'
        ORDER BY
            4,
            3,
            2,
            1
    )
    SELECT
        report_quarter,
        merchant_id,
        merchant_name,
        category
    FROM
        dat
    WHERE
        rnk <= 50
    ORDER BY
        4,
        2,
        3
);
