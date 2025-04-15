-- CREDIT DECISION TESTING -- run separately for each reason listed in select
select --PRICING_MISMATCH,
--EXPOSURE_MISMATCH,
--TERM_MISMATCH,
DOWNPAYMENT_MISMATCH,
count(application_id),
from AP_CUR_CRDRISK_G.CURATED_CREDIT_RISK_GREEN.MQF_TRANSACTION_TESTING
where application_id not in (select order_token from app_cash_3pr.afterpay.test_attempt_exclusions)
and application_date between '2025-03-01' and '2025-03-31'
group by 1



--- IDV DECISION
with base as
(
select 
consumer_consumer_uuid consumer_uuid,
order_detail_order_token order_token,
convert_timezone('UTC','America/Los_Angeles', DATE_TRUNC('second', EVENT_INFO_EVENT_TIME)) IDV_DATETIME,
result,
rejection_reason
FROM ap_raw_green.green.RAW_C_E_CL_IDV_RESULT 
WHERE 1=1
and to_date(convert_timezone('UTC','America/Los_Angeles', DATE_TRUNC('second', EVENT_INFO_EVENT_TIME))) between '2025-03-01' and '2025-03-31'
and result in ('FAILED') 
)
select count(distinct order_token) incorrectly_failed
from base 
where rejection_reason is null
