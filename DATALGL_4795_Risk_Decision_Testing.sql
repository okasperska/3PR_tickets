WITH RECURSIVE date_spine AS (
    SELECT DATE '2025-03-01' as date_month
    UNION ALL
    SELECT DATEADD(month, 1, date_month)
    FROM date_spine
    WHERE date_month < CURRENT_DATE()
),

idv_metrics AS (
    SELECT 
        DATE_TRUNC('month', convert_timezone('UTC','America/Los_Angeles', EVENT_INFO_EVENT_TIME)) as month_date,
        COUNT(DISTINCT CASE WHEN result = 'FAILED' THEN order_detail_order_token END) as total_idv_declined,
        COUNT(DISTINCT CASE WHEN result = 'FAILED' AND rejection_reason IS NULL 
              THEN order_detail_order_token END) as incorrect_idv_declined,
        COUNT(DISTINCT CASE WHEN result = 'FAILED' AND rejection_reason IS NOT NULL 
              THEN order_detail_order_token END) as correct_idv_declined
    FROM ap_raw_green.green.RAW_C_E_CL_IDV_RESULT
    GROUP BY 1
),

credit_metrics AS (
    SELECT 
        DATE_TRUNC('month', application_date) as month_date,
        -- Credit Decision Counts
        COUNT(CASE WHEN decision_status = 'APPROVED' THEN application_id END) as total_credit_approved,
        COUNT(CASE WHEN decision_status = 'DECLINED' THEN application_id END) as total_credit_declined,
        0 as incorrect_credit_declined,  -- Placeholder for incorrect declines
        
        -- Secondary Testing (for all applications)
        COUNT(CASE WHEN PRICING_MISMATCH = 1 THEN application_id END) as incorrect_pricing,
        COUNT(CASE WHEN EXPOSURE_MISMATCH = 1 THEN application_id END) as incorrect_exposure,
        COUNT(CASE WHEN TERM_MISMATCH = 1 THEN application_id END) as incorrect_term,
        COUNT(CASE WHEN DOWNPAYMENT_MISMATCH = 1 THEN application_id END) as incorrect_downpayment,
        
        COUNT(*) as total_applications
    FROM AP_CUR_CRDRISK_G.CURATED_CREDIT_RISK_GREEN.MQF_TRANSACTION_TESTING
    WHERE application_id NOT IN (SELECT order_token FROM app_cash_3pr.afterpay.test_attempt_exclusions)
    GROUP BY 1
)

SELECT 
    d.date_month as "Report Month",
    'Pay Monthly' as "Product",
    'Primary' as "Testing",
    '# Declined by IDV' as "Testing Detail",
    'IDV criteria' as "Rule in Credit Policy",
    COALESCE(im.correct_idv_declined, 0) as "Correct",
    COALESCE(im.incorrect_idv_declined, 0) as "Incorrect",
    COALESCE(im.total_idv_declined, 0) as "Total",
    CASE 
        WHEN COALESCE(im.total_idv_declined, 0) = 0 THEN 0 
        ELSE ROUND(100.0 * im.incorrect_idv_declined / im.total_idv_declined, 2)
    END as "Incorrect%"
FROM date_spine d
LEFT JOIN idv_metrics im ON d.date_month = im.month_date

UNION ALL

SELECT 
    d.date_month,
    'Pay Monthly',
    'Primary',
    '# Approved by Credit',
    'Credit Underwriting & Pricing',
    NULL,  -- No correct/incorrect split for approvals
    NULL,
    COALESCE(cm.total_credit_approved, 0),
    NULL
FROM date_spine d
LEFT JOIN credit_metrics cm ON d.date_month = cm.month_date

UNION ALL

SELECT 
    d.date_month,
    'Pay Monthly',
    'Primary',
    '# Declined by Credit',
    'Credit Underwriting & Pricing',
    COALESCE(cm.total_credit_declined - cm.incorrect_credit_declined, 0),
    COALESCE(cm.incorrect_credit_declined, 0),
    COALESCE(cm.total_credit_declined, 0),
    CASE 
        WHEN COALESCE(cm.total_credit_declined, 0) = 0 THEN 0 
        ELSE ROUND(100.0 * cm.incorrect_credit_declined / cm.total_credit_declined, 2)
    END
FROM date_spine d
LEFT JOIN credit_metrics cm ON d.date_month = cm.month_date

UNION ALL

SELECT 
    d.date_month,
    'Pay Monthly',
    'Secondary',
    'Pricing',
    'Credit Underwriting & Pricing',
    COALESCE(cm.total_applications - cm.incorrect_pricing, 0),
    COALESCE(cm.incorrect_pricing, 0),
    COALESCE(cm.total_applications, 0),
    CASE 
        WHEN COALESCE(cm.total_applications, 0) = 0 THEN 0 
        ELSE ROUND(100.0 * cm.incorrect_pricing / cm.total_applications, 2)
    END
FROM date_spine d
LEFT JOIN credit_metrics cm ON d.date_month = cm.month_date

UNION ALL

SELECT 
    d.date_month,
    'Pay Monthly',
    'Secondary',
    'Risk-based Exposure Cap',
    'Risk-based Exposure Criteria',
    COALESCE(cm.total_applications - cm.incorrect_exposure, 0),
    COALESCE(cm.incorrect_exposure, 0),
    COALESCE(cm.total_applications, 0),
    CASE 
        WHEN COALESCE(cm.total_applications, 0) = 0 THEN 0 
        ELSE ROUND(100.0 * cm.incorrect_exposure / cm.total_applications, 2)
    END
FROM date_spine d
LEFT JOIN credit_metrics cm ON d.date_month = cm.month_date

UNION ALL

SELECT 
    d.date_month,
    'Pay Monthly',
    'Secondary',
    'Loan Term',
    'Term Offering',
    COALESCE(cm.total_applications - cm.incorrect_term, 0),
    COALESCE(cm.incorrect_term, 0),
    COALESCE(cm.total_applications, 0),
    CASE 
        WHEN COALESCE(cm.total_applications, 0) = 0 THEN 0 
        ELSE ROUND(100.0 * cm.incorrect_term / cm.total_applications, 2)
    END
FROM date_spine d
LEFT JOIN credit_metrics cm ON d.date_month = cm.month_date

UNION ALL

SELECT 
    d.date_month,
    'Pay Monthly',
    'Secondary',
    'Downpayment',
    'Downpayment rule',
    COALESCE(cm.total_applications - cm.incorrect_downpayment, 0),
    COALESCE(cm.incorrect_downpayment, 0),
    COALESCE(cm.total_applications, 0),
    CASE 
        WHEN COALESCE(cm.total_applications, 0) = 0 THEN 0 
        ELSE ROUND(100.0 * cm.incorrect_downpayment / cm.total_applications, 2)
    END
FROM date_spine d
LEFT JOIN credit_metrics cm ON d.date_month = cm.month_date

ORDER BY "Report Month", 
CASE "Testing"
    WHEN 'Primary' THEN 1
    WHEN 'Secondary' THEN 2
END,
CASE "Testing Detail"
    WHEN '# Declined by IDV' THEN 1
    WHEN '# Approved by Credit' THEN 2
    WHEN '# Declined by Credit' THEN 3
    WHEN 'Pricing' THEN 4
    WHEN 'Risk-based Exposure Cap' THEN 5
    WHEN 'Loan Term' THEN 6
    WHEN 'Downpayment' THEN 7
END;
