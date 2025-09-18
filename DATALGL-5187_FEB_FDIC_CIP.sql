----basic request code - leveregae project evolution

select 
disposition_of_application
,Partner_ID
,Application_ID
,Loan_Account_Number
,Customer_ID
,First_Name
,Last_Name
,SSN_or_FedID
,Date_of_Birth
,Street_Address1
,Street_Address2
,City
,State
,Zipcode_plus_four
,Application_Date
,Application_Decision_Date
,Approved_Loan_Amount_or_Initial_Credit_Limit
,CIP_Match_Flag
,Loan_Acceptance_Date
,Merchant
,OFAC_Soft_Hit
,OFAC_Check_Date
,Pend_Reason
,Product
,'NA' as Pend_Date
,'NA' as Pend_Clear_Date
From cash_3pr_pii.afterpay.feb_de_applications
where application_id in (
'002.k3ofserub933gva55g9i14jmdp27u0gi1bi33qq7pq63sda1__2wV6AViHFUWmVrXshtJDcVFe8sK',
'002.2r7gvbcipep96k9sr9fbmuocj3cai2i164ttjqtbt9nves9f__2wGdtbjDVrungF1VhqmFBA3TrqJ',
'002.uvmbad9nk64ee80k5rjd0be8dv9p18a0snn2qrbvup5o6bln__2vs51dVSXGjj41ZMOvAjfIH6vm6',
'002.bre9s0eh4rlrlhuo201gpbho0a0jekngc6gi5vi9ahvgpan__2vN1Q77NHBYpbZJCsTY8MzOYM3R'
)

---- check decisioning if there was anything in pend (VERIFIED nothong dodgy, approved right away)
select * from ap_cur_crdrisk_g.curated_credit_risk_green.consumer_lending_decision
where order_token in (
'002.k3ofserub933gva55g9i14jmdp27u0gi1bi33qq7pq63sda1',
'002.2r7gvbcipep96k9sr9fbmuocj3cai2i164ttjqtbt9nves9f',
'002.uvmbad9nk64ee80k5rjd0be8dv9p18a0snn2qrbvup5o6bln',
'002.bre9s0eh4rlrlhuo201gpbho0a0jekngc6gi5vi9ahvgpan'
)

---- verify address if no change (VERIFIED - no address change since the data generated)
select a.ID, b.uuid , a.given_names, a.surname, a.date_of_birth, a.ADDRESS1, a.ADDRESS2 
from ap_raw_red_csmr.red.D_CONSUMER__okasperska_DSL3_SV a
join ap_raw_green.green.D_CONSUMER b
on a.id = b.id
where b.uuid in (
'e6d1ac29-ee16-43ea-8505-1fa29e6f748b',
'b64becb9-c225-4961-8b56-a90087f5fdad',
'b3c03cdc-b6f9-4112-a1c7-378bfa2dd90d',
'16ffeb44-4de9-482e-9393-f23e615536d8'
)


---- verify IDV (VERIFIED - no address change)
select --*
key_consumer_uuid,
to_date(convert_timezone('UTC','America/Los_Angeles',EVENT_INFO_EVENT_TIME))
from ap_raw_green.green.RAW_C_E_IDV_INSTANT_ID
--from ap_raw_red_csmr.red.RAW_C_E_IDV_INSTANT_ID__okasperska_DSL3_SV
where key_consumer_uuid in (
'e6d1ac29-ee16-43ea-8505-1fa29e6f748b',
'b64becb9-c225-4961-8b56-a90087f5fdad',
'b3c03cdc-b6f9-4112-a1c7-378bfa2dd90d',
'16ffeb44-4de9-482e-9393-f23e615536d8'
)
