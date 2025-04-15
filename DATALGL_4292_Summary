WITH macro_variables AS (
    SELECT
        '2024-06-30'::DATE as start_dte,
        '2024-07-31'::DATE as end_dte
),

step1 AS (
    SELECT
        country_code,
        count(distinct consumer_uuid) as Account_cnt_period_start,
        sum(acc_limit) as total_limit_start
    FROM PERSONAL_OKASPERSKA.public.anz_limits_start
    WHERE acc_closed_flag = 'N'
    AND acc_wo_flag = 'N'
    AND self_exclusion_flag = 'N'
    AND acc_created_date <= (SELECT start_dte FROM macro_variables)
    GROUP BY 1
),

step2 AS (
    SELECT
        country_code,
        count(distinct consumer_uuid) as account_cnt_period_end,
        sum(acc_limit) as total_limit_period_end
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end
    WHERE acc_closed_flag = 'N'
    AND acc_wo_flag = 'N'
    AND self_exclusion_flag = 'N'
    AND acc_created_date <= (SELECT end_dte FROM macro_variables)
    GROUP BY 1
),

step3 AS (
    SELECT
        country_code,
        count(distinct consumer_uuid) as new_account_cnt,
        sum(acc_limit) as limit_increase_due_to_new_accounts
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end
    WHERE acc_closed_flag = 'N'
    AND acc_wo_flag = 'N'
    AND self_exclusion_flag = 'N'
    AND acc_created_date BETWEEN (SELECT start_dte + 1 FROM macro_variables) AND (SELECT end_dte FROM macro_variables)
    GROUP BY 1
),

step4 AS (
    SELECT
        e.country_code,
        count(distinct e.consumer_uuid) as reactivated_account_cnt,
        SUM(e.acc_limit) as limit_increase_due_to_reactivation
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end e
    LEFT JOIN PERSONAL_OKASPERSKA.public.anz_limits_start s ON e.consumer_id = s.consumer_id
    WHERE e.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N'
    AND e.acc_created_date <= (SELECT start_dte FROM macro_variables)
    AND (
        (e.se_date BETWEEN (SELECT start_dte + 1 FROM macro_variables) AND (SELECT end_dte FROM macro_variables)
         AND s.self_exclusion_flag = 'Y')
        OR
        s.acc_closed_flag = 'Y'
    )
    GROUP BY 1
),

step6 AS (
    SELECT
        e.country_code,
        count(distinct s.consumer_uuid) as deactivated_accounts,
        sum(s.acc_limit) as limit_decrease_due_to_deactivation
    FROM PERSONAL_OKASPERSKA.public.anz_limits_start s
    LEFT JOIN PERSONAL_OKASPERSKA.public.anz_limits_end e ON s.consumer_uuid = e.consumer_uuid
    WHERE s.acc_created_date <= (SELECT start_dte FROM macro_variables)
    AND s.acc_closed_flag = 'N'
    AND s.acc_wo_flag = 'N'
    AND s.self_exclusion_flag = 'N'
    AND (e.acc_closed_flag = 'Y' OR e.acc_wo_flag = 'Y' OR e.self_exclusion_flag = 'Y')
    GROUP BY 1
),

step7 AS (
    SELECT
        e.country_code,
        count(distinct e.consumer_id) as account_cnt_limit_increased,
        sum(coalesce(e.acc_limit,0) - coalesce(s.acc_limit,0)) as limit_increase
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end e
    LEFT JOIN PERSONAL_OKASPERSKA.public.anz_limits_start s ON s.consumer_uuid = e.consumer_uuid
    WHERE e.acc_closed_flag = 'N' and s.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N' and s.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N' and s.self_exclusion_flag = 'N'
    AND coalesce(e.acc_limit,0) > coalesce(s.acc_limit,0)
    AND s.acc_created_date <= (SELECT start_dte FROM macro_variables)
    GROUP BY 1
),

step8 AS (
    SELECT
        e.country_code,
        count(distinct e.consumer_id) as account_cnt_limit_decreased,
        sum(coalesce(e.acc_limit,0) - coalesce(s.acc_limit,0)) as limit_decrease
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end e
    LEFT JOIN PERSONAL_OKASPERSKA.public.anz_limits_start s ON s.consumer_uuid = e.consumer_uuid
    WHERE e.acc_closed_flag = 'N' and s.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N' and s.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N' and s.self_exclusion_flag = 'N'
    AND coalesce(e.acc_limit,0) < coalesce(s.acc_limit,0)
    AND s.acc_created_date <= (SELECT start_dte FROM macro_variables)
    GROUP BY 1
),

step9 AS (
    SELECT
        e.country_code,
        count(distinct e.consumer_id) as account_cnt_limit_unchanged,
        sum(coalesce(e.acc_limit,0) - coalesce(s.acc_limit,0)) as limit_unchanged
    FROM PERSONAL_OKASPERSKA.public.anz_limits_end e
    LEFT JOIN PERSONAL_OKASPERSKA.public.anz_limits_start s ON s.consumer_uuid = e.consumer_uuid
   WHERE e.acc_closed_flag = 'N' and s.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N' and s.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N' and s.self_exclusion_flag = 'N'
    AND coalesce(e.acc_limit,0) = coalesce(s.acc_limit,0)
    AND s.acc_created_date <= (SELECT start_dte FROM macro_variables)
    GROUP BY 1
)

SELECT
    COALESCE(s1.country_code, s2.country_code, s3.country_code, s4.country_code,
             s6.country_code, s7.country_code, s8.country_code, s9.country_code) as country_code,
    s1.Account_cnt_period_start,
    s1.total_limit_start,
    s2.account_cnt_period_end,
    s2.total_limit_period_end,
    s3.new_account_cnt,
    s3.limit_increase_due_to_new_accounts,
    s4.reactivated_account_cnt,
    s4.limit_increase_due_to_reactivation,
    s6.deactivated_accounts,
    s6.limit_decrease_due_to_deactivation,
    s7.account_cnt_limit_increased,
    s7.limit_increase,
    s8.account_cnt_limit_decreased,
    s8.limit_decrease,
    s9.account_cnt_limit_unchanged,
    s9.limit_unchanged,
    -- Calculate net movement
    COALESCE(s2.account_cnt_period_end,0) - COALESCE(s1.Account_cnt_period_start,0) as net_account_movement,
    COALESCE(s2.total_limit_period_end,0) - COALESCE(s1.total_limit_start,0) as net_limit_movement
FROM step1 s1
FULL OUTER JOIN step2 s2 ON s1.country_code = s2.country_code
FULL OUTER JOIN step3 s3 ON s1.country_code = s3.country_code
FULL OUTER JOIN step4 s4 ON s1.country_code = s4.country_code
FULL OUTER JOIN step6 s6 ON s1.country_code = s6.country_code
FULL OUTER JOIN step7 s7 ON s1.country_code = s7.country_code
FULL OUTER JOIN step8 s8 ON s1.country_code = s8.country_code
FULL OUTER JOIN step9 s9 ON s1.country_code = s9.country_code
ORDER BY country_code;
