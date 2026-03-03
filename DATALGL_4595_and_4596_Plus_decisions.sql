select 
consumer_uuid,
approved,
ineligible_type,
ineligible_reason,
ineligible_subreason,
decline_detail,
decision_time,
case when rnk = 1 then subscription_created_at else null end as subscription_created_at,
case when rnk = 1 then event_type else null end as event_type,
case when rnk = 1 then start_date else null end as start_date
from (

                            select 
                            dec.key_consumer_uuid consumer_uuid,
                            dec.approved,
                            dec.ineligible_type,
                            dec.ineligible_reason,
                            dec.ineligible_subreason,
                            dec.decline_detail,
                            CONVERT_TIMEZONE('UTC', 'America/Los_Angeles', dec.event_info_event_time) decision_time,
                            CONVERT_TIMEZONE('UTC', 'America/Los_Angeles', sub.event_info_event_time) subscription_created_at ,
                            ROW_NUMBER() OVER (PARTITION BY dec.key_consumer_uuid, to_date(decision_time) ORDER BY subscription_created_at DESC) = 1 as rnk,
                            sub.event_type,
                            sub.start_date
                            FROM AP_RAW_GREEN.green.raw_c_e_membership_decision dec
                            left join AP_RAW_GREEN.green.raw_c_e_membership_subscription sub
                                on dec.key_consumer_uuid = sub.consumer_uuid 
                                and subscription_created_at >= decision_time
                                and to_date(subscription_created_at) = to_date(decision_time) --since there is no bespoke key tha can be used to join these tables, we need to rely on this fuzzy match. The subscription is normally created within a couple of minutes after the decision. To be safe - check for outliers that happenned just around midnight.
                                and sub.event_type = 'SUBSCRIBED' 
                            where dec.key_consumer_uuid in () -- insert list of uuids here

)
--where to_date(decision_time) >= '2024-01-01' -- adjust the decision date if needed
order by 1,7,8
