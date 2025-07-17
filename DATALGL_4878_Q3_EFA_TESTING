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
--and to_date(convert_timezone('UTC','America/Los_Angeles',key_event_info_event_time)) between '2025-02-01' and '2025-04-30'
and order_token in 
            ('002.v6qqllhdacm9ckd76ppfj64btifqgdlfaa4o2o4ebtsk2a0p',
'002.3vvsai11ii8mbb1u45oa9ngsvjm0v585momq0dp1us9sm0lj',
'002.atuc8eqis9l3339rq3la3qje51ekovsnbl25a85i36k5ubgk',
'002.dam9m66t2a0bjp49ktn0bg30iunqp8ilmsoub51qdd3b23gb',
'002.ahikddnt9ij97adffug6dbtjb40u0n2o9oi3n59hhanoass7',
'002.s6gn74o1o7rnfan7e7q6mjhuj80nuit429d5bdi6p1kcios2',
'002.npm6ldan9utldnfdq8o8sohnjkpp2tmglrg7pg7v5g2ko7',
'002.inhlte11kmgcvtepgid46vku95c84ufu4ourlaff62j06i6r',
'002.v6rn8e0ks9c48vgmdudtruh8rvf7tpf36sc56kosqa0itt2a',
'002.md86qv87edd5jl6etgaooecfb1vbhpeghkj72vrp7jd4kda3',
'002.67kcgemqme61srjjl39e73jije7orje4u5kargiif3skftqr',
'002.dhraia4kgvs1ebm4c6gn20t1v1uj57iep0o4aui00qappq8c',
'002.g79p3gte4abfh0j4f8s7m15f3u5pj8fvo9ciu6rpss02frm2',
'002.tde7s91t3pufqj16hjotvvibp13kt2i1prnf45rl7kpip1mi',
'002.3ksp5jd5tlu8n7cca565d4f0mgceb0vj6l1igngb6091q2nv',
'002.hc8hvn43gfffo7du37qnri6a6ufq4aho9kjpovd4r5gfibt1',
'002.n9ssba7bohvphkj02ucm0fjtgfcej1nf6od0e5l845v6cier',
'002.3lpkk9kavqqtalpep64tcovhp0ok2ar7osp2cbosr4cj4cif',
'002.utc3gqjot8ckm72mv2aioqstkreqi1t5d2aaa857iujdtoc2',
'002.gouc4rsa7sq3ak0cim5vcij3ru02g3lvdaqnd5ivf64j83sp',
'002.u9ir31ra450r3malquic3imubb94c0nvtm0tgd4801mfihik',
'002.qlesgt8oamm4gtjvv5jk2aomptp7eei56rholsu57cchmgo6',
'002.qbkdhsu0dlrusve5eu69t0oolfo9u5ghrh8glddkpbh2mk4h',
'002.jq37f23pluvnq6btac96q7gigdb7np446c7a41uf9p39q16l',
'002.num54ms4dav58mqrsc90m9onl2rna2dlem1rjmll0t1dmqu0',
'002.e5k42n3ev08gricj75kpdmqilsmi5cn1i5dc8nr7vugsr7gh',
'002.6f7rnb1sdspdrkr2l2flu73qdqpggvtqrf15m4ihun0hieec',
'002.2rmm9qsmfqg2jpagfa33s21pi5huoceg3e3ctkfja50m1cbl',
'002.5hrjrp893kjs3h0i34tfhmvjchb4hlbkv4ueq1b4aijk9u1c',
'002.r2m7plckpve386ac6v96ejs1rveh3ckmc43fsg7uf02jmkji',
'002.herarl493g67a7rb0744sps0uhkfhnulqc3fni1f2q0do4t7',
'002.qal252mhi4k76c5cjf71cbqrqorf0n6eh8du23r1bcp111dr',
'002.q87e8upmam2bd6ulb9kb94m15isfhqeqnhkkn3ttne6fhnjf',
'002.a922g5c9f4b74nthq193khi0ovqpb90t4vbi9hc473e7g6r',
'002.51dt6eq6km89nfcrrbhmb2gl45quemhb3o2rukrivl090l8u',
'002.8f7p6mcagbkvbna0r8paepk0j4k3m1u5q3brfpbughv874o6',
'002.j1vbkgjchu76ortpsf82hfsufo6pmimeeat62saj17f8u963',
'002.1hu6tiirk5ubi9sbui6ojfsqavjkrla7n60geb78smagt11v',
'002.gctohvmsflrhmfi4sirhj690umj84iaplnplot5q0ggfkalj',
'002.r5gb3iok5o5phqf5rqj4kt0bcar5f3ems2l0lhfna46po3ij',
'002.fskmqncompapu2essa9ui0slaq5sj71p1uoa6pvq2vk77fr5',
'002.j1o03lhp29q33ujodbvjrpnojnf1pr7ulssrp104tn21mp4v',
'002.7jh4hthjabfg8vtrfqcegk61i8gdo8rbgn6btbna6l7p8ss5',
'002.mogl6a8ffpl2e0in6nvftm6r3vntho8g6l7q3siq4g6ppi99',
'002.fvpt2bl0buc2cf63eid24u0dnb6isl5iar3usa7eatvioe2v',
'002.mqasvp7kqfc498pddet783hm2f9d6iamint8aat6joen7pgh',
'002.hr2bra5ihqrrg4899o4sdbluffu0ms34g2jaq94ghdro2n34',
'002.3ah82dpr5a9dmlkav02kkhbdke0lctach7h25bum0rqbljnl',
'002.ppbj3kefhfc12fm22oa9f3c4lrmb1fq6eroae36lqse25m6i',
'002.osfphh3enludhr6kqgcg6a3m7sgtob39q33rbk0vqic017bq',
'002.3umtt9v2888c8k8hbu6pg0om0ao8ukc5v829h6fge2p5d1qg',
'002.cvmqt8tkt18kes6oej5rir817ikndjr6nccldsab4666iobm',
'002.9390kubgldm7k1ql7q2m4c15fqq208nmt1bm043alnjipup7',
'002.th56crpoi696up72jlcjkl92gp76jol5j96v8pcu431nr8qu',
'002.o8cq7r619nbrim299veqntfiabfrqnms55ioage8tdqfaq9a',
'002.rsqlhq75cmqd79nq27k2cfahnfeo6k5fpfrm4h2hsgihcd3p',
'002.tc5mo5idb6bha2sqrpspbmgjhtbjr3e7df3sos501h48bbck',
'002.dvaq6t9alhqttqj2m8f8ristilov2t0aa6rloi157uac837t',
'002.cks4kfl2f7ov6l1mtg9170duomf6gsqgipjsp17tccap5omo',
'002.btndc9hg04hi3h3cpo2hhno6bd43jlii26a996no0t0sf85a',
'002.57olt311vjl63h2e03nj9ma7rjg2rpba12csurf6c7brlgbd',
'002.vt7ibmuo9nnti9s0ph7miglo129tnobsjbco2po8dh7fkuu3',
'002.ruqq05l6go93d8j15k6lb9p8q258fh3og175aq6rdijfketr',
'002.b2gi07083djtd3c2qh703huup05r1qjlviljon09oid0bdkd',
'002.uv6gcjb085lmrf08jd02mioberbijdcm1j1llj1876m0j0oe',
'002.1id8hc794f7tr7k85aadhee4283d416kj0bvqvj0skvuvcks',
'002.ugbqh2ag2b0m1cvera4qst6d1p99c1nvbtebbf2bnihfb5o',
'002.j6avcvrh2m1bkrtgnefra14hva4it1lu5vd7gbohf2f0ln4s',
'002.e4h3brvk3cdcm3gqr21om6snt0e6hk6edfqqrcv2aj70acia',
'002.cnnmrn9mbb5l9ade1sg7t1ktoca9q5o08k7ectleosp0c5op',
'002.kp8eqsm1v7dmpt3m9umpate10r3vmmk2366lec07ubbi35vk',
'002.cmg9rb1kjus8jf693rhs3eg953oi532v8s2nggvsriqvenak',
'002.6r21jamptdllur738eu2jhi89ive9154kommp53gcefsllnd',
'002.7kq5pt4leqibsm15kep7km1tkrhul44n4qhn1q1hn69b0qsd',
'002.lf35q06ur44rc0rmdiq6ueiq8u2ju1df1j0fbuavjg71ugkq',
'002.nqbvnhrtglibm9tqf1v17hegds5h31ie6ububh656sbdi8ie',
'002.qqqsigbtisqbesqajddl9qkdhdch0c5pkrbputna2dg90ndv',
'002.q3ddep2qttd46h8bsob4rfgtfvcmdnqbnr84dl2eau4rto2c',
'002.22mjrtnk0fvov9htc686l547e6sq7jq8hotpuul2thci3smb',
'002.1e899d046lurkfbaibposfirim6ob0vka2qhe76oi05sujjp',
'002.ujj038qebja842r248p1mk1cas2f2bv3037814c6hv58aa71',
'002.11vl6qpkt23e4ip6hq8kave2chftuh8hv5ce983lll92mpvf',
'002.rje851h4ns4cs36oi95bbejo4tdsh88fsk6r8vu9stvoffma',
'002.g6h492hql7l7ibb3kov4spubqfs7irac6lmohlesfon5c7c0',
'002.ntkl4dqil09hjt8gv1l0hqrt9pqpgqh1urgmae17ovfrh23d',
'002.jjj2lv5jrkvpmcn8iadcjh5cqg3opl7dbq0nkvhjgpk2mcrf',
'002.n44l8f8bsr9krrnk17al34hf8it0khchfilp48jnposm64tc',
'002.alg1j93rfr5pa6eeofqvj6hv5p75jujck3smgt78jhue60k0',
'002.1vta0lv72j3ev6gmda4r58hg463l4394n716ommsgj7e67f7',
'002.gh0ivp52kopo4uapn0ulhm0fje47vuusu3mf0ish4i0be6kk',
'002.gu1r4035cu2l13bd3nuo909fal87h06q056m3qp1rok03tgs',
'002.pqvmrek4s2nq4j4o0htgg90vgpkirvkgsmmb07n3c1r90oai',
'002.a2nm6ifa970ajdd0qck7bj609isgvtc2hff4mfhd2mrmn9nc',
'002.s63pjn22i700h9vc76htui16lekcgu4b8fbjd04vkpp32f1s',
'002.tsf4fk6mdol3b45dc0urpo0c767uha6iqp59p3pbqtse5fqu',
'002.800r9f45o4tcnehvu65ob3urrfatrddltffsasm15qprhhh3',
'002.pgh89pnp2dcei3lav4f1lj4uvimifev71affcgjrqgn37tbm',
'002.goujlab5g9mn3nq62223pfl85hh04v0riao40pbblonk8fae',
'002.8ck3hgpiugqqao5mf6gsj12pbkurjhcgms2fk7ibf9s6g6eb'
)
            
--qualify ROW_NUMBER()OVER(PARTITION BY  consumer_uuid, created_time, merchant_id, decline_main_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME desc) = 1 --dedupping based on rules used in MQF prior to Q1 2025 to avoid confusion
--qualify ROW_NUMBER()OVER(PARTITION BY  order_token, consumer_uuid, decline_main_sub_reason ORDER BY  KEY_EVENT_INFO_EVENT_TIME asc) = 1 -- project evolution dedupping method
        
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


