with BASE as --- taken straight from project evolution code
(
select order_token, 
consumer_uuid,
convert_timezone('UTC','America/Los_Angeles', key_event_info_event_time) application_datetime,
decision_status,
decline_main_reason,
decline_main_sub_reason,
cast(convert_timezone('UTC','America/Los_Angeles',dateadd('MS',created_date,'1970-01-01')) as date) as created_time,  
to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) application_date,
ROW_NUMBER()OVER(PARTITION BY  consumer_uuid, created_time, merchant_id, decline_main_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME desc) as rnk --dedupping based on rules used in MQF prior to Q1 2025 to avoid confusion
-- ROW_NUMBER()OVER(PARTITION BY  order_token, consumer_uuid, decline_main_sub_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME asc) as rnk -- project evolution dedupping method
FROM AP_CUR_CRDRISK_G.CURATED_CREDIT_RISK_GREEN.consumer_lending_decision
where country_code = 'US'
and to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) between '2025-02-01' and '2025-04-30'
and order_token in 
            (select order_token 
            from AP_CUR_CRDRISK_G.CURATED_CREDIT_RISK_GREEN.consumer_lending_decision 
            where decline_main_reason = 'EXPERIAN_EFA_DECLINE'
            and to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) between '2025-02-01' and '2025-04-30')
            
qualify ROW_NUMBER()OVER(PARTITION BY  consumer_uuid, created_time, merchant_id, decline_main_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME desc) = 1 --dedupping based on rules used in MQF prior to Q1 2025 to avoid confusion
-- ROW_NUMBER()OVER(PARTITION BY  order_token, consumer_uuid, decline_main_sub_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME asc) as rnk = 1 -- project evolution dedupping method
        
),

ROBOCALL as
(select base.order_token, base.consumer_uuid, 
convert_timezone('UTC','America/Los_Angeles', robo.event_info_event_time) as efa_call_datetime, 
robo.robocall_result
from ap_raw_green.green.raw_c_e_consumer_extended_fraud_alert_status robo
join base
on base.order_token = robo.order_token and base.consumer_uuid = robo.consumer_consumer_uuid
where 1=1
QUALIFY ROW_NUMBER() OVER (PARTITION BY robo.consumer_consumer_uuid, robo.order_token ORDER BY robo.event_info_event_time DESC) = 1
)


select
c.order_token,
c.consumer_uuid,
c.application_datetime,
c.decision_status,
c.decline_main_reason,
c.decline_main_sub_reason,
rb.efa_call_datetime,
rb.robocall_result,
fo.order_transaction_status,
fo.id order_id,
fo.payment_type,
xo.dropout_reason
from base c
left join AP_CUR_XOOP_G.PAY_MONTHLY.M_ATM_ATTEMPT_MASTER xo
     on c.order_token = xo.transaction_token and c.consumer_uuid = xo.uuid and c.rnk = 1
left join ap_raw_green.green.f_order fo
     on c.order_token =fo.order_token --and fo.payment_type = 'PCL' -- some attempts may have ended up as a BNPL order
     and c.decision_status = 'APPROVED'
left join robocall rb
     on c.order_token = rb.order_token and c.consumer_uuid = rb.consumer_uuid 
     --and (c.decision_status = 'APPROVED' or (c.decision_status = 'DECLINED' and rb.robocall_result <> 'VERIFIED'))
     and (c.decision_status = 'DECLINED' and c.decline_main_reason = 'EXPERIAN_EFA_DECLINE')
order by 1,3



