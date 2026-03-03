--- straight forward Pay Monthly
select zticket_id, uuid consumer_uuid, consumer_id, consumer_state, ticket_created_date, order_id, product_type, issue_category, type_of_investigation, ticket_solved_date, account_outcome
from AP_CUR_XOOP_G.OPERATION.M_ATO_DL_SUMMARY
where country_code = 'US'
and ticket_created_date between '2024-09-01' and '2024-11-30'
and (product_type like '%PAY_MONTHLY%')




--- unknown product type but consumer have had PM order
select ato.zticket_id, ato.uuid consumer_uuid, fo.consumer_id, ato.consumer_state, ato.ticket_created_date, ato.order_id, ato.product_type, ato.issue_category, ato.type_of_investigation, ato.ticket_solved_date,  account_outcome, max(fo.order_date) last_pm_order_date 
from AP_CUR_XOOP_G.OPERATION.M_ATO_DL_SUMMARY ato
join ap_raw_green.green.f_order fo
on ato.consumer_id = fo.consumer_id and fo.order_date <= ato.ticket_created_date and fo.payment_type = 'PCL' and order_transaction_status = 'Approved'
where ato.country_code = 'US'
and ato.ticket_created_date between '2024-09-01' and '2024-11-30'
and product_type is null
group by ato.zticket_id, ato.uuid, fo.consumer_id, ato.consumer_state, ato.ticket_created_date, ato.order_id, ato.product_type, ato.issue_category, ato.type_of_investigation, ato.ticket_solved_date,  account_outcome
