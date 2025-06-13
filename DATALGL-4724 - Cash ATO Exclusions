/******************************************************************************
Basic code inspired (heavily by Chloe's code on litigation/24Q3 CFPB ROG 41 Pull Forward/CFPB Restitution Population (i)/app_cash_3pr.cfpb.restitution_exclusion_p2p_viral_verbiage.sql
Goal: Identify cases that have one of # defined by Chris Phillips so that we can fuether limit the entire redress popluation
*******************************************************************************/



CREATE OR REPLACE TABLE app_cash_3pr.cfpb.pop_dead_end_ato_exclusions AS

(
    WITH
        base    AS (
            SELECT DISTINCT COALESCE(original_created_at, created_at)                      AS created_at
                          , entity_token                                                   AS customer_token
                          , TRIM(reason)                                                   AS regulator_comment
                          , REGEXP_SUBSTR_ALL(regulator_comment, ('([^.]|^)([0-9]{8,9})')) AS case_num_array,
                          LISTAGG(tag.value, ', ') WITHIN GROUP (ORDER BY tag.value) AS EXCLUSION_REASON
            FROM regauditlogs.raw_oltp.audit_logs logs,
            LATERAL FLATTEN(INPUT => REGEXP_SUBSTR_ALL(reason, '#\\$?ATO[_\\w]+')) tag  -- Extracts all ATO tags
            
            WHERE reason LIKE ANY (
                                   '%#$ATO_INV_ATO%','%#$ATO_RESET_CONFIRMED%','%#$ATO_REIMBURSMENT%','%#$ATO_INV_NA%','%#$ATO_Clawback%','%#$ATO_Clawback_Balance%','%#ATO_CERT_REVIEWED%','%#ATO_DL_mismatchname%','%#$ATO_INV_AP%','%#$ATO_SECURED_FFATO%','%#ATO_SLA_CO%','%#$ATO_INV_SPONSOR%','%#$ATO_INV_CaC%','%#ATO_P2P_Escalation%','%#$ATO_NA_Reimbursed%','%#$ATO_INV_ATO2%','%#$ATO_CL_Badrecip%','%ATO_BL_BADRECIP%','%ATO_BL_CONFIRMED%','%ATO_CL_CONFIRMED%','%ATO_CL_CSMF%','%ATO_CL_PATTERN%','%ATO_DL_BADRECIP%','%ATO_INV_802%','%ATO_INV_803%','%ATO_LOCK_CLEAR%','%ATO_NA_REIMBURSED%'
                )
            AND NOT (
                        REGEXP_COUNT(reason, '#\\$ATO_RESET_CONFIRMED') > 0 
                        AND REGEXP_COUNT(reason, '#\\$ATO_INV_LATO') > 0   
                    ) ---- this is to address the comment in the spreadsheet to disregard #$ATO_RESET_CONFIRMED if included with #$ATO_INV_LATO
            GROUP BY 1,2,3,4
            )
            
      , flatten AS (
            SELECT DISTINCT base.* EXCLUDE (case_num_array)
                          , REGEXP_REPLACE(TRIM(f.value::VARCHAR), '[^0-9]', '') AS case_number
            FROM                                                         base
               , LATERAL FLATTEN(INPUT => case_num_array, OUTER => TRUE) f
            )
    SELECT flt.*
         , cases.case_id        AS case_id
         , cases.customer_token AS sc_customer_token
    FROM flatten                                                  flt
             LEFT JOIN app_datamart_cco.public.cash_support_cases cases
                       ON flt.case_number = cases.case_number
    );

-- estimate the impact
select count (distinct pop.case_id) 
from app_cash_3pr.cfpb.pop_dead_end_combined_case_list pop
where case_id in (select case_id from app_cash_3pr.cfpb.pop_dead_end_ato_exclusions) 



---- to address the caveat:
CREATE OR REPLACE TABLE app_cash_3pr.cfpb.pop_dead_end_ato_exclusions_2 AS
(
WITH base AS (
    SELECT DISTINCT 
        COALESCE(original_created_at, created_at) AS created_at,
        entity_token AS customer_token,
        TRIM(reason) AS regulator_comment,
        REGEXP_SUBSTR_ALL(regulator_comment, ('([^.]|^)([0-9]{8,9})')) AS case_num_array,
        LISTAGG(tag.value, ', ') WITHIN GROUP (ORDER BY tag.value) AS EXCLUSION_REASON
    FROM regauditlogs.raw_oltp.audit_logs logs,
    LATERAL FLATTEN(INPUT => REGEXP_SUBSTR_ALL(reason, '#\\$?ATO[_\\w]+')) tag
    WHERE reason LIKE ANY (
        '%#$ATO_INV_ATO%',
        '%#$ATO_RESET_CONFIRMED%',
        '%#$ATO_REIMBURSMENT%',
        '%#$ATO_INV_NA%',
        '%#$ATO_Clawback%',
        '%#$ATO_Clawback_Balance%',
        '%#ATO_CERT_REVIEWED%',
        '%#ATO_DL_mismatchname%',
        '%#$ATO_INV_AP%',
        '%#$ATO_SECURED_FFATO%',
        '%#ATO_SLA_CO%',
        '%#$ATO_INV_SPONSOR%',
        '%#$ATO_INV_CaC%',
        '%#ATO_P2P_Escalation%',
        '%#$ATO_NA_Reimbursed%',
        '%#$ATO_INV_ATO2%',
        '%#$ATO_CL_Badrecip%',
        '%ATO_BL_BADRECIP%',
        '%ATO_BL_CONFIRMED%',
        '%ATO_CL_CONFIRMED%',
        '%ATO_CL_CSMF%',
        '%ATO_CL_PATTERN%',
        '%ATO_DL_BADRECIP%',
        '%ATO_INV_802%',
        '%ATO_INV_803%',
        '%ATO_LOCK_CLEAR%',
        '%ATO_NA_REIMBURSED%'
    )
    AND reason NOT LIKE '%#$ATO_INV_LATO%'
    GROUP BY 
        COALESCE(original_created_at, created_at),
        entity_token,
        TRIM(reason),
        REGEXP_SUBSTR_ALL(regulator_comment, ('([^.]|^)([0-9]{8,9})'))
),
flatten AS (
    SELECT DISTINCT 
        base.* EXCLUDE (case_num_array),
        REGEXP_REPLACE(TRIM(f.value::VARCHAR), '[^0-9]', '') AS case_number
    FROM base,
    LATERAL FLATTEN(INPUT => case_num_array, OUTER => TRUE) f
),
case_tag_check AS (
    SELECT 
        case_number
    FROM (
        SELECT 
            REGEXP_REPLACE(TRIM(f.value::VARCHAR), '[^0-9]', '') AS case_number,
            COUNT(DISTINCT CASE WHEN reason LIKE '%#$ATO_RESET_CONFIRMED%' THEN logs.created_at END) AS has_reset_confirmed,
            COUNT(DISTINCT CASE WHEN reason LIKE '%#$ATO_INV_LATO%' THEN logs.created_at END) AS has_inv_lato
        FROM regauditlogs.raw_oltp.audit_logs logs,
        LATERAL FLATTEN(INPUT => REGEXP_SUBSTR_ALL(reason, ('([^.]|^)([0-9]{8,9})'))) f
        GROUP BY 1
    )
    WHERE has_reset_confirmed > 0 AND has_inv_lato > 0
)
SELECT 
    flt.*
      , cases.case_id        AS case_id
         , cases.customer_token AS sc_customer_token
    FROM flatten                                                  flt
    LEFT JOIN app_datamart_cco.public.cash_support_cases cases
                       ON flt.case_number = cases.case_number

WHERE NOT EXISTS (
    SELECT 1 
    FROM case_tag_check ctc 
    WHERE ctc.case_number = flt.case_number
)
);
