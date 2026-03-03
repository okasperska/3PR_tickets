
---VOIDED IN FULL
with v_base as 
(
select --a.id order_id,
a.order_token,
c.uuid consumer_uuid,
a.order_date application_date,
a.order_amount,
--b.created_date,
sum(b.amount) voided_amount
from ap_raw_green.green.f_order a
left join ap_raw_green.green.f_order_payment_event b
on a.id = b.order_id
join ap_raw_green.green.d_consumer c
on a.consumer_id = c.id
where a.order_transaction_status = 'Approved'
and a.payment_type = 'PCL'
and a.order_date between '2024-04-01' and '2024-06-30'
--and a.order_date = b.created_date
and b.ORDER_PAYMENT_EVENT_TYPE_DESC in ('VOIDED')
and a.country_code = 'US'
group by 1,2,3,4
),

VOIDED as

(
select order_token, 
consumer_uuid, 
application_date,
'VOIDED' as dropout_reason
from v_base
where order_amount = voided_amount
),


----APPROVED by credit risk but declined later


C_BASE as --- taken straight from project evolution code
( select * from
        (select order_token, 
        consumer_uuid,
        KEY_EVENT_INFO_ID,
        offers_loan_amount_amount,
        key_event_info_event_time,
        decision_status,
        merchant_id,
        offers_target_apr,
        offers_term, 
        offers_eligibility, 
        credit_report_uuid, 
        test_group, 
        decline_main_reason,
        decline_main_sub_reason,
        cast(convert_timezone('UTC','America/Los_Angeles',dateadd('MS',created_date,'1970-01-01')) as date) as created_time,  
        to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) application_date,
        ROW_NUMBER()OVER(PARTITION BY  consumer_uuid, created_time, merchant_id, decline_main_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME desc) as rnk --dedupping based on rules used in MQF prior to Q1 2025 to avoid confusion
        -- ROW_NUMBER()OVER(PARTITION BY  order_token, consumer_uuid, decline_main_sub_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME asc) as rnk -- project evolution dedupping method
        FROM AP_CUR_CRDRISK_G.CURATED_CREDIT_RISK_GREEN.consumer_lending_decision
        where country_code = 'US') 
        WHERE rnk = 1  
        and to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) between '2024-04-01' and '2024-06-30'
),

CREDIT_DECLINES as 
(                        
select 
order_token, 
consumer_uuid, 
application_date
from c_base
where decision_status = 'APPROVED' -- signifies approved loans
order by application_date
),


OTHER_DECLINES as
(
SELECT
TRANSACTION_TOKEN,
TRANSACTION_DATE,
DROPOUT_REASON,
UUID
from AP_CUR_XOOP_G.PAY_MONTHLY.M_ATM_ATTEMPT_MASTER
WHERE MERCHANT_COUNTRY = 'US'
AND TRANSACTION_DATE BETWEEN '2024-04-01' and '2024-06-30'
AND DROPOUT_REASON IN (
'Invalid Payment details',
'Insufficient Funds',
'Risk - Fraud'
,'Payment error'
)
AND STATUS_REASON NOT IN ('CROSS_COUNTRY_CARD_REJECTION','TOPAZ_PURCHASE_ENQUIRE_REJECTION')
),

further_declines as
(
select 
a.order_token, 
a.consumer_uuid, 
a.application_date,
b.DROPOUT_REASON
from credit_declines a
join other_declines b
on a.consumer_uuid = b.uuid and a.order_token = b.transaction_token
)

--- FINAL OUTPUT 

select * from voided union select * from further_declines;


------- SAMPLE FOLLOW UP

---VOIDED IN FULL
with v_base as 
(
select --a.id order_id,
a.order_token,
c.uuid consumer_uuid,
a.order_date application_date,
a.order_amount,
--b.created_date,
'VOIDED' as voided_flag,
sum(b.amount) voided_amount
from ap_raw_green.green.f_order a
left join ap_raw_green.green.f_order_payment_event b
on a.id = b.order_id
join ap_raw_green.green.d_consumer c
on a.consumer_id = c.id
where a.order_transaction_status = 'Approved'
and a.payment_type = 'PCL'
--and a.order_date between '2024-04-01' and '2024-06-30'
and b.ORDER_PAYMENT_EVENT_TYPE_DESC in ('VOIDED')
and a.country_code = 'US'
and a.order_token in 
('002.2r4isthbpica5dlteecjg9uacc81v05gitpvpfkjp2md8bag',
'002.j1snn1q4nddjhnaos1u0dd3iq4fhi5f7eje7661868sk1695',
'002.krqnam7426pepkahiem24fkocltmghsegu6e9hd32sm87u9m',
'002.tb6c9oo8e6a27fefkl3q6lt26g94cpunp6p1iaeevo7blau2',
'002.c2k6vlhnrf7hh3hhadu3vkhb95htrdvd86fg32ravksvd6pc',
'002.gli3ff3kdg4qs2jh7obnhk6ll1km3jc156v3vit979a464ns',
'002.l1olikntkbu2odh0pab95knl0kt07pn66ttd5994sqvl13c2',
'002.5un2o1rkob3r059hakhtoomdi8lpu5qu03tidsg1ags1qm7g',
'002.pmp9j4ugjv6lkkkhncha7eujuu4gjkj19bbcsh3m3vtjuhpr',
'002.b47i1a38lvms1mteco1poknsomc4j5b3vkdb63q1eg6s3hfh',
'002.jns00j8qm4a1mhhfn3gs9hjadq0s3s59ktgrfegi2g9e1vnr',
'002.mfcfbqnbgs3t822gsf2uk7v4m7f26oski8ikn1peqr90kif5',
'002.eo0an4n0omspqmca679mmja704n4ue08dr44ghabookjsnms',
'002.fmjv9iarg3s1bnjmkmhp4od05ur3qjfh2qr52m16vh2s9t8n',
'002.k00f00qbd8pslbf0mubufp8j7it7v36hbaujgg7n0hidihn2',
'002.aoqno48sick0fi7fgcjlnfocbl7jdstijqadb7fq4039mqq6',
'002.9t3r484vgt3m3abfn286iooriu3llliae7u9aabhc78qu2li',
'002.2fvu39v35gpauacsjr8pggaf0vm2hpufr1eglbvlojiv91cu',
'002.u1jg5teorh2j5qfj1j9pmtsrnb2rnlj6fifnqo3sppm8fo2k',
'002.p5om552frrbhqf8vfsi316n2bqmbdp7cfsi15su4kdh00cpe',
'002.bh5659ud1nhcqphi66ovsq0ef34unic718412u30tke52kig',
'002.akgaiacuelueo6tp2qv5brmp77rf0vffnfc2057glotcl1qj',
'002.h89c82lf3nj49tsmpo6r9q62j2acrtr23fi0m8nrb08jkg7p',
'002.i6cto82tooce110tlf87705oht4tp7gkba1gn3ae2omq5tg0',
'002.jrm15f5kqvq5gbn1a7bc678cifi5r7lfkdqco0rf93tll1d0',
'002.k3jbenl7cm7t74ssoi3lsjch2d5u58dtip18e7egaqs06jti',
'002.i2p1umim2prpa40u1uib0jqa7pq46i81pq2qc2k9td5liuut',
'002.paldnba1u41mj0g6en1t3u2044v9iv0k9j2soqvrmn6t20ic',
'002.i1fcj9ti5t1qcs86iu9p5f663oihfs0d2utos48lkrv52nce',
'002.qpii2m7it9leguc8kr9ofj3s9gp0o4p3f1qdc6701j77ltab',
'002.rugke03adgkfka7n5rbro0kkofdoodfq77l97hqalbhd7too',
'002.eoublct3kqe1mh43r4urq8t4nrqj2gloksnqj9be292pglno',
'002.p0bff1ku6g0mkujnr3fa5hfit4d165l7cm69egfpdqtagrkr',
'002.9lcso5n2pvg8gr7e5medpgaan37qn36j43tk0smbk6jomhl2',
'002.h9ot8dutqskbsesek8rb7okf4c5c8rf7t6f9o6vdmt9dmfta',
'002.5r7g90j4dsenhh9l14ikn6930cm273bk7a404h2ill0v5q3l',
'002.m9qn3pu17i8jmvo4d4b7mkmer1h2k65boj6anb86a7fdbmk0',
'002.o8kr2ab1drkfh08pnkh4smfih957eccnuui9gj43bapvoa3t',
'002.ffjepvfpks0v6dthh6cf0p46823v1c8fhi5a9f3dp4kd5egj',
'002.ovbl6g4enaqq32u0iqujpna7mljivd13cb2q85sja9h84an3',
'002.2i044ot5s8g4h45bdff4rin8gfs27jhbdi67jucua0ugdio7',
'002.8ffgb1rnr1k3rnj6urh2i20bmfg71mjsbpou2sg5m8jvhe1a',
'002.ghaega7bjt508ca9fgh99pbq56k9c45o5qsbs4eq7blgun2',
'002.gbbf49tsv0l5j0hdffkaolugqlktqefe4f1ejjqmlslp95sf',
'002.kkq7jh60u92helomkp5hgut60r30l18jfkt9aqfru2qj3ol1',
'002.3pvjuc9c5uicta7tfnj1rgg52umnu6ce3umv9mecstpretde',
'002.luhe1hsbcdnr60iqklu0rdcolvg1qcjg4032qbe9h4aiaqd7',
'002.47v6iot9is23lgf7ioa1dvnambru1m05ksgulet7329pqkcc',
'002.m43v53u9utokh3j635sr4v10bjfs19hjo4rop9fo9ve3ucgj',
'002.9errak8cado94cgvq7o6al70g6ql96hoic84qkrnepvvm0f4',
'002.g28ii9v6eeougl6dl89ugmlm2nt63kv13l9bjmcm0h41bgpc',
'002.1ssplfp15ausojtirk0p262aq7qr8pshc5mh2tp6huq8alfe',
'002.3tou8e10po5eih8pdrc0it06lpdjemfe6d8u60eg78p7ahj4',
'002.1lktu5mgleaffn4oufkq7hvkmr085h8npdg4v8pcerbfe4sj',
'002.utjnm0fqhquutp92mmrn01f979ajgl40ou2lqchmg11kd434',
'002.nhg3iafutm3kb60trjlhelvarkrgkdtgq80gf68ndg0qvrtj',
'002.ub90ntosfusg9abig41m2s3sjc9rhvgdo14iqsgg38f9ckpq',
'002.1tp5gj5v6ue7kf3baphqghe7nt08c63gfum87iba2ess01r3',
'002.dnt8ltcdhmk07df066e5h8sdptcc6jl1782eo27kv7tj1n3c'
)
group by 1,2,3,4
),




----APPROVED by credit risk but declined later


C_BASE as --- taken straight from project evolution code
( select * from
        (select order_token, 
        consumer_uuid,
        KEY_EVENT_INFO_ID,
        offers_loan_amount_amount,
        key_event_info_event_time,
        decision_status,
        merchant_id,
        offers_target_apr,
        offers_term, 
        offers_eligibility, 
        credit_report_uuid, 
        test_group, 
        decline_main_reason,
        decline_main_sub_reason,
        cast(convert_timezone('UTC','America/Los_Angeles',dateadd('MS',created_date,'1970-01-01')) as date) as created_time,  
        to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) application_date,
        ROW_NUMBER()OVER(PARTITION BY  consumer_uuid, created_time, merchant_id, decline_main_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME desc) as rnk --dedupping based on rules used in MQF prior to Q1 2025 to avoid confusion
        -- ROW_NUMBER()OVER(PARTITION BY  order_token, consumer_uuid, decline_main_sub_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME asc) as rnk -- project evolution dedupping method
      FROM AP_CUR_CRDRISK_G.CURATED_CREDIT_RISK_GREEN.consumer_lending_decision
        where country_code = 'US') 
        WHERE rnk = 1  
        --and to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) between '2024-04-01' and '2024-06-30'
        and order_token in 
        ('002.2r4isthbpica5dlteecjg9uacc81v05gitpvpfkjp2md8bag',
'002.j1snn1q4nddjhnaos1u0dd3iq4fhi5f7eje7661868sk1695',
'002.krqnam7426pepkahiem24fkocltmghsegu6e9hd32sm87u9m',
'002.tb6c9oo8e6a27fefkl3q6lt26g94cpunp6p1iaeevo7blau2',
'002.c2k6vlhnrf7hh3hhadu3vkhb95htrdvd86fg32ravksvd6pc',
'002.gli3ff3kdg4qs2jh7obnhk6ll1km3jc156v3vit979a464ns',
'002.l1olikntkbu2odh0pab95knl0kt07pn66ttd5994sqvl13c2',
'002.5un2o1rkob3r059hakhtoomdi8lpu5qu03tidsg1ags1qm7g',
'002.pmp9j4ugjv6lkkkhncha7eujuu4gjkj19bbcsh3m3vtjuhpr',
'002.b47i1a38lvms1mteco1poknsomc4j5b3vkdb63q1eg6s3hfh',
'002.jns00j8qm4a1mhhfn3gs9hjadq0s3s59ktgrfegi2g9e1vnr',
'002.mfcfbqnbgs3t822gsf2uk7v4m7f26oski8ikn1peqr90kif5',
'002.eo0an4n0omspqmca679mmja704n4ue08dr44ghabookjsnms',
'002.fmjv9iarg3s1bnjmkmhp4od05ur3qjfh2qr52m16vh2s9t8n',
'002.k00f00qbd8pslbf0mubufp8j7it7v36hbaujgg7n0hidihn2',
'002.aoqno48sick0fi7fgcjlnfocbl7jdstijqadb7fq4039mqq6',
'002.9t3r484vgt3m3abfn286iooriu3llliae7u9aabhc78qu2li',
'002.2fvu39v35gpauacsjr8pggaf0vm2hpufr1eglbvlojiv91cu',
'002.u1jg5teorh2j5qfj1j9pmtsrnb2rnlj6fifnqo3sppm8fo2k',
'002.p5om552frrbhqf8vfsi316n2bqmbdp7cfsi15su4kdh00cpe',
'002.bh5659ud1nhcqphi66ovsq0ef34unic718412u30tke52kig',
'002.akgaiacuelueo6tp2qv5brmp77rf0vffnfc2057glotcl1qj',
'002.h89c82lf3nj49tsmpo6r9q62j2acrtr23fi0m8nrb08jkg7p',
'002.i6cto82tooce110tlf87705oht4tp7gkba1gn3ae2omq5tg0',
'002.jrm15f5kqvq5gbn1a7bc678cifi5r7lfkdqco0rf93tll1d0',
'002.k3jbenl7cm7t74ssoi3lsjch2d5u58dtip18e7egaqs06jti',
'002.i2p1umim2prpa40u1uib0jqa7pq46i81pq2qc2k9td5liuut',
'002.paldnba1u41mj0g6en1t3u2044v9iv0k9j2soqvrmn6t20ic',
'002.i1fcj9ti5t1qcs86iu9p5f663oihfs0d2utos48lkrv52nce',
'002.qpii2m7it9leguc8kr9ofj3s9gp0o4p3f1qdc6701j77ltab',
'002.rugke03adgkfka7n5rbro0kkofdoodfq77l97hqalbhd7too',
'002.eoublct3kqe1mh43r4urq8t4nrqj2gloksnqj9be292pglno',
'002.p0bff1ku6g0mkujnr3fa5hfit4d165l7cm69egfpdqtagrkr',
'002.9lcso5n2pvg8gr7e5medpgaan37qn36j43tk0smbk6jomhl2',
'002.h9ot8dutqskbsesek8rb7okf4c5c8rf7t6f9o6vdmt9dmfta',
'002.5r7g90j4dsenhh9l14ikn6930cm273bk7a404h2ill0v5q3l',
'002.m9qn3pu17i8jmvo4d4b7mkmer1h2k65boj6anb86a7fdbmk0',
'002.o8kr2ab1drkfh08pnkh4smfih957eccnuui9gj43bapvoa3t',
'002.ffjepvfpks0v6dthh6cf0p46823v1c8fhi5a9f3dp4kd5egj',
'002.ovbl6g4enaqq32u0iqujpna7mljivd13cb2q85sja9h84an3',
'002.2i044ot5s8g4h45bdff4rin8gfs27jhbdi67jucua0ugdio7',
'002.8ffgb1rnr1k3rnj6urh2i20bmfg71mjsbpou2sg5m8jvhe1a',
'002.ghaega7bjt508ca9fgh99pbq56k9c45o5qsbs4eq7blgun2',
'002.gbbf49tsv0l5j0hdffkaolugqlktqefe4f1ejjqmlslp95sf',
'002.kkq7jh60u92helomkp5hgut60r30l18jfkt9aqfru2qj3ol1',
'002.3pvjuc9c5uicta7tfnj1rgg52umnu6ce3umv9mecstpretde',
'002.luhe1hsbcdnr60iqklu0rdcolvg1qcjg4032qbe9h4aiaqd7',
'002.47v6iot9is23lgf7ioa1dvnambru1m05ksgulet7329pqkcc',
'002.m43v53u9utokh3j635sr4v10bjfs19hjo4rop9fo9ve3ucgj',
'002.9errak8cado94cgvq7o6al70g6ql96hoic84qkrnepvvm0f4',
'002.g28ii9v6eeougl6dl89ugmlm2nt63kv13l9bjmcm0h41bgpc',
'002.1ssplfp15ausojtirk0p262aq7qr8pshc5mh2tp6huq8alfe',
'002.3tou8e10po5eih8pdrc0it06lpdjemfe6d8u60eg78p7ahj4',
'002.1lktu5mgleaffn4oufkq7hvkmr085h8npdg4v8pcerbfe4sj',
'002.utjnm0fqhquutp92mmrn01f979ajgl40ou2lqchmg11kd434',
'002.nhg3iafutm3kb60trjlhelvarkrgkdtgq80gf68ndg0qvrtj',
'002.ub90ntosfusg9abig41m2s3sjc9rhvgdo14iqsgg38f9ckpq',
'002.1tp5gj5v6ue7kf3baphqghe7nt08c63gfum87iba2ess01r3',
'002.dnt8ltcdhmk07df066e5h8sdptcc6jl1782eo27kv7tj1n3c'
)
        
)








select
c.order_token,
c.consumer_uuid,
c.application_date,
c.decision_status,
c.decline_main_reason,
c.decline_main_sub_reason,
fo.order_transaction_status,
xo.dropout_reason,
v.voided_flag
from c_base c
left join v_base v
on c.order_token = v.order_token and c.consumer_uuid = v.consumer_uuid
left join AP_CUR_XOOP_G.PAY_MONTHLY.M_ATM_ATTEMPT_MASTER xo
on c.order_token = xo.transaction_token and c.consumer_uuid = xo.uuid
left join ap_raw_green.green.f_order fo
on c.order_token =fo.order_token and fo.payment_type = 'PCL' -- some attempts may have ended up as a BNPL order
order by 1,3
