/***************************************************
1. Run the code for  PERSONAL_OKASPERSKA.public.anz_limits_start using the previous month end date in macro_variabled CTE
2. Run the code for CREATE OR REPLACE table  PERSONAL_OKASPERSKA.public.anz_limits_end using the current month end date in macro_variabled CTE
3. Run the Summary
***************************************************/

USE WAREHOUSE ADHOC__XLARGE;
CREATE OR REPLACE table  PERSONAL_OKASPERSKA.public.anz_limits_start as
--CREATE OR REPLACE table  PERSONAL_OKASPERSKA.public.anz_limits_end as
(

WITH 
macro_variables as 
(
SELECT
   
'2025-02-28' ::DATE as end_dte -- previous month end date
--'2025-03-31' ::DATE as end_dte --current month end date
     
)

,BASE as 
(
select dc.id consumer_id,
dc.country_code,
dc.uuid consumer_uuid,
dc.created_date acc_created_date,
lim.ACCOUNT_LIMIT_AMOUNT acc_limit,
max(order_date) as recent_order_date
from ap_raw_green.green.d_consumer dc
left join AP_CUR_RISKFEC_G.credit.cust_limit_daily_prod_au lim
on dc.uuid = lim.consumer_uuid and to_date(lim.batch_dttm) = (select end_dte from macro_variables)
left join ap_raw_green.green.f_order fo
on dc.id = fo.consumer_id and fo.order_date <= (select end_dte from macro_variables)
where dc.country_code in ('AU', 'NZ')
and dc.created_date <= (select end_dte from macro_variables)
group by 1,2,3,4,5
)

,                               ACC_CLOSED_DATES_STG AS -- dates when a consumer account was closed with balance due to bankruptcy, ATO etc
                                (
                                select a.consumer_id, b.uuid consumer_uuid, max(a.created_date) closed_date, max(a.created_datetime) closed_datetime
                                from ap_raw_green.green.f_consumer_note a
                                join ap_raw_green.green.d_consumer b
                                on a.consumer_id = b.id
                                where 1=1 
                                and b.country_code in ('AU', 'NZ')
                                and ((note LIKE '%to ''CLOSED''%' AND note LIKE '%Status changed from%') or note like '%Account closed/disabled%')
                                and a.created_date <= (select end_dte from macro_variables)
                                group by 1,2
                                )
        
                                ,ACC_REINSTATED_DATES AS -- limited cases when an account gets reinstated when disputed liability is withdrawn
                                (
                                select a.consumer_id, b.uuid consumer_uuid, max(a.created_datetime) reinst_datetime
                                from ap_raw_green.green.f_consumer_note a
                                join ap_raw_green.green.d_consumer b
                                on a.consumer_id = b.id
                                where 1=1 
                                and b.country_code in ('AU', 'NZ')
                               and ((note LIKE '%to ''REGISTERED''%' AND note LIKE '%Status changed from%') or (note LIKE '%to REGISTERED%' AND note LIKE '%Status Change from%'))
                                and a.created_date <= (select end_dte from macro_variables)
                                group by 1,2
                                )

, ACC_CLOSED_DATES AS
(
select a.consumer_id, a.consumer_uuid, a.closed_date
from ACC_CLOSED_DATES_STG a
left join ACC_REINSTATED_DATES b
on a.consumer_id = b.consumer_id
WHERE b.reinst_datetime is null or b.reinst_datetime < a.closed_datetime
)

, ACC_WRITTEN_OFF_DATES AS -- dates when an order was written off based on 180DO rule
(
select 
wo.consumer_id,
max(wo.event_date) wo_date
from AP_RAW_GREEN.GREEN.F_WRITE_OFF_EVENTS wo
where wo.event_type = 'Write Off'
and wo.write_off_event_source in ('Payment','Late Fee')
and wo.gdp_region = 'AU'
and wo.event_date <= (select end_dte from macro_variables)
group by 1
)
, SELF_EXCLUDE as
(
select * from
                        (
                        select 
                        a.CONSUMER_ACCOUNT_REFERENCE_CONSUMER_ID consumer_id, 
                        to_date(case when b.country_code = 'AU' then  (convert_timezone('UTC', 'Australia/Melbourne', a.EVENT_INFO_EVENT_TIME))
                                     when b.country_code = 'NZ' then  (convert_timezone('UTC', 'Pacific/Auckland', a.EVENT_INFO_EVENT_TIME))
                                     else null end) as status_change_date,
                        STATUS_CHANGED_TO,
                        row_number() over (partition by a.CONSUMER_ACCOUNT_REFERENCE_CONSUMER_ID order by a.EVENT_INFO_EVENT_TIME desc) rnk 
                        FROM AP_RAW_GREEN.GREEN.RAW_C_E_CONSUMER_SELF_EXCLUSION a
                        JOIN AP_RAW_GREEN.GREEN.d_consumer b
                        on a.CONSUMER_ACCOUNT_REFERENCE_CONSUMER_ID = b.id
                        where b.country_code in ('AU', 'NZ')
                        and status_change_date <= (select end_dte from macro_variables)
                        )
where rnk = 1
)

, STAGING as
(
select
base.country_code,
base.consumer_id,
base.consumer_uuid,
base.acc_created_date,
base.acc_limit,
base.recent_order_date,
cl.closed_date,
wo.wo_date,
se.status_change_date se_date,
se.status_changed_to
from base
left join acc_closed_dates cl
on base.consumer_uuid = cl.consumer_uuid
left join acc_written_off_dates wo
on base.consumer_id = wo.consumer_id
left join self_exclude se
on base.consumer_id = se.consumer_id

)

SELECT
country_code,
consumer_id,
consumer_uuid,
acc_created_date,
closed_date,
wo_date,
se_date,
case when country_code = 'AU' and acc_limit is null and acc_created_date < '2025-06-09' then 600 
     when country_code = 'AU' and acc_limit is null and acc_created_date >= '2025-06-10' then null
     when country_code = 'NZ' and acc_limit is null and acc_created_date < '2024-07-23' then 600 
     when country_code = 'NZ' and acc_limit is null and acc_created_date >= '2024-07-23' then null 
     else acc_limit end as acc_limit,            

case when closed_date is null then 'N' else 'Y' end as acc_closed_flag,

case when wo_date is null then 'N' else 'Y' end as acc_wo_flag,

case when status_changed_to in ('DEACTIVATED','ACCOUNT_CLOSED') then 'Y'
     when (status_changed_to in ('REACTIVATED','ACCOUNT_REOPENED') or status_changed_to is null) then 'N'
     else null end as self_exclusion_flag
FROM STAGING
);



---- SUMMARY
WITH macro_variables AS (
    SELECT
        '2025-02-28'::DATE as start_dte,
        '2025-03-31'::DATE as end_dte
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
    WHERE e.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N'
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
    WHERE e.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N'
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
    WHERE e.acc_closed_flag = 'N'
    AND e.acc_wo_flag = 'N'
    AND e.self_exclusion_flag = 'N'
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
