INSERT INTO BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_KIA_FEAT
(
with score_month as (
select distinct 
"Month_Start_Date"
from
(select distinct dateadd('month',1,max("Month_Start_Date")) as "Month_Start_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE)
union
(select max("Month_Start_Date") as "Month_Start_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE
)
)
,
store_product_month as (
select distinct a."Month_Start_Date"
,b."Store_Code"
,b."Store_State_Code"
,b."Product_Code"
,b."MAP_PLANT_CODE"
from score_month a
cross join (select distinct "Store_Code","Store_State_Code","Product_Code","MAP_PLANT_CODE"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE) b
)
,
days_in_month as (
select distinct 
"Month_Start_Date",
datediff('day',"Month_Start_Date",dateadd('month',1,"Month_Start_Date")-1)+1 as "Days_In_Month",
dateadd('month',1,"Month_Start_Date")-1 as "Month_End_Date"
from store_product_month
)
,
holidays as (
SELECT DISTINCT
"Month_Start_Date",
"State",
"Month_Holiday_Cnt",
"Month_First_Holiday_Date",
"Month_Last_Holiday_Date",
"Month_Holiday_DaysInBetween",
LEAD("Month_Holiday_Cnt") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Next_Month_Holiday_Cnt",
LEAD("Month_First_Holiday_Date") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Next_Month_First_Holiday_Date",
Lag("Month_Holiday_Cnt") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Previous_Month_Holiday_Cnt",
Lag("Month_Last_Holiday_Date") OVER (PARTITION BY "State" ORDER BY "Month_Start_Date") "Previous_Month_Last_Holiday_Date",
"Next_Month_First_Holiday_Date"-"Month_End_Date" as "Days_to_Next_Month_First_Holiday",
"Month_Start_Date"-"Previous_Month_Last_Holiday_Date" as "Days_from_Previous_Month_Last_Holiday"
from
(select 
distinct 
a.*,
nvl(b."Month_Holiday_Cnt",0) as "Month_Holiday_Cnt",
b."Month_First_Holiday_Date",
b."Month_Last_Holiday_Date",
b."Month_Holiday_DaysInBetween"
from (SELECT c.*,
b."State"
FROM days_in_month c
CROSS JOIN (SELECT DISTINCT "Store_State_Code" AS "State" FROM store_product_month) b) a
left join core.AU_PUBLIC_HOLIDAYS_MONTH_VW b
on a."Month_Start_Date"=b."Month_Start_Date"
AND a."State"=b."State"
)
)
,
plant_prod_avail as (
select distinct 
b."Plant_State",
a."Plant_Code",
right(a."Product_Code",8) "Product_Code",
c."Month_Start_Date",
c."Days_In_Month",
date(a."MCS_ETA_Date") "MCS_ETA_Date",
a."Planned_Delivery_Days",
least(case when c."Month_Start_Date"<=date(a."MCS_ETA_Date") then date(a."MCS_ETA_Date")-c."Month_Start_Date"+1
           when c."Month_Start_Date">date(a."MCS_ETA_Date") then 0
           else 0 end,c."Days_In_Month") as "Sigma_MCS_Days_In_Month",
least(case when c."Month_Start_Date"<=date(a."MCS_ETA_Date") then date(a."MCS_ETA_Date")-c."Month_Start_Date"+1
           when c."Month_Start_Date">date(a."MCS_ETA_Date") then 0
           else 0 end,c."Days_In_Month") as "Sigma_OOS_Days_In_Month"
from edp_prod.pres."Dim_Product_Plant_Attribute" a
cross join (select distinct "Month_Start_Date","Days_In_Month" from days_in_month) c
join edp_prod.pres."Dim_Plant" b
on a."Plant_Code"=b."Plant_Code" 
)
,
state_prod_avail as (
select 
"Plant_State",
"Product_Code",
"Month_Start_Date",
max("Sigma_MCS_Days_In_Month") "Sigma_State_MCS_Days_In_Month",
max("Sigma_OOS_Days_In_Month") "Sigma_State_OOS_Days_In_Month"
from plant_prod_avail
group by 1,2,3
)
,
promo as (
SELECT DISTINCT 
a."Promotion_Brief_Detail_Key",
a."Blueprint_Banner_Key",
b."Banner_Abbreviation",
upper(b."Banner_Name") "Banner_Name",
CASE WHEN "Banner_Abbreviation"='WL' THEN 'WLF'
      WHEN "Banner_Abbreviation"='PS' THEN 'PSP'
      WHEN "Banner_Abbreviation"='CK' THEN 'CHK'
      WHEN upper("Banner_Abbreviation") IN ('UKN','UNKNOWN','N/A','NA','BLANK','NOT APPLICABLE') THEN null
      ELSE "Banner_Abbreviation" END AS "Mapped_Banner_Code",
a."Product_Key",
right(c."Product_Code",8) "Product_Code",
a."Supplier_Key",
date(a."Buy_Period_Start_Date_Key",'yyyymmdd') as "Wholesale_Promo_Start_Date",
date(a."Buy_Period_End_Date_Key",'yyyymmdd') as "Wholesale_Promo_End_Date",
date_trunc('month',"Wholesale_Promo_Start_Date") as "Wholesale_Promo_Start_Month",
date_trunc('month',"Wholesale_Promo_End_Date") as "Wholesale_Promo_End_Month",
date(a."Buy_Period_End_Date_Key",'yyyymmdd')-date(a."Buy_Period_Start_Date_Key",'yyyymmdd')+1 "Wholesale_Promo_Duration_Days",
a."Promotion_Minimum_Buy_Qty" AS "Promo_Minimum_Buy_Qty_Per_Order",
a."Promotion_Discount_Percentage" AS "Wholesale_Promo_Discount_Percentage",
date(a."Promo_Start_Date_Key",'yyyymmdd') as "Retail_Promo_Start_Date",
date(a."Promo_End_Date_Key",'yyyymmdd') as "Retail_Promo_End_Date",
date_trunc('month',"Retail_Promo_Start_Date") as "Retail_Promo_Start_Month",
date_trunc('month',"Retail_Promo_End_Date") as "Retail_Promo_End_Month",
date(a."Promo_End_Date_Key",'yyyymmdd')-date(a."Promo_Start_Date_Key",'yyyymmdd')+1 "Retail_Promo_Duration_Days",
a."Saving_Percentage" "Retail_Promo_Discount_Percentage"
FROM "EDP_PROD"."PRES"."Fact_Blueprint_Promotion" a
JOIN "EDP_PROD"."PRES"."Dim_Blueprint_Banner" b
ON a."Blueprint_Banner_Key" = b."Blueprint_Banner_Key"
JOIN edp_prod.pres."Dim_Product" c
ON a."Product_Key"=c."Product_Key"
and c."Product_Key">0
where a."Promotion_Brief_Detail_Key"!=-1
)
,
hist_dmnd_banner as (
select distinct 
a."Month_Start_Date",
a."Store_Code",
--case when b."Demand_Group_Code" is not null then b."Demand_Group_Code"
      --when b."Demand_Group_Code" is null and upper(c."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then  c."Demand_Group_Code"
      --else null end as "Demand_Group_Code",
case when b."Banner_Group_Code" is not null then b."Banner_Group_Code"
      when b."Banner_Group_Code" is null and upper(c."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then  c."Banner_Group_Code"
      else null end as "Banner_Group_Code"
from --BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
store_product_month a
left join 
(
select distinct
a."Month_Start_Date",
a."Store_Code",
--case when upper(b."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then b."Demand_Group_Code"
      --else null end as "Demand_Group_Code",
case when upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK') then b."Banner_Group_Code"
      else null end as "Banner_Group_Code",
a."Month_Start_Date" - b."Effective_Start_Date" as "Effective_Days"
from --BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
store_product_month a
left join core.DIM_CUSTOMER_STORE_HIST b
ON a."Store_Code"=b."Store_Code" 
and a."Month_Start_Date">=b."Effective_Start_Date"
and a."Month_Start_Date"<b."Effective_End_Date"
QUALIFY Row_Number() OVER (PARTITION BY 
a."Month_Start_Date",
a."Store_Code"
----"Demand_Group_Code",
--"Banner_Group_Code"
ORDER BY "Effective_Days")=1
) b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
left join edp_prod.pres."Dim_Customer_Retail_Store" h
ON a."Store_Code" = h."Store_Code"
left join edp_prod.pres."Dim_Customer" c
on h."Site_Link_Code"=c."Site_Link_Code"
and c."Distribution_Channel_Name"='WHOLESALE'
)
,
wholesale_promo as (
select distinct 
a."Month_Start_Date",
dateadd('month',1,a."Month_Start_Date")-1 as "Month_End_Date",
--b."Demand_Group_Code",
b."Banner_Group_Code",
a."Product_Code",
e."Promotion_Brief_Detail_Key",
e."Wholesale_Promo_Start_Date",
e."Wholesale_Promo_End_Date",
e."Wholesale_Promo_Start_Month",
e."Wholesale_Promo_End_Month",
e."Wholesale_Promo_Duration_Days",
e."Promo_Minimum_Buy_Qty_Per_Order",
case when a."Month_Start_Date"=e."Wholesale_Promo_Start_Month" then e."Wholesale_Promo_Start_Date"
     when a."Month_Start_Date">e."Wholesale_Promo_Start_Month" then a."Month_Start_Date"
     end as "Monthly_Wholesale_Promo_Start_Date",
case when a."Month_Start_Date"=e."Wholesale_Promo_End_Month" then e."Wholesale_Promo_End_Date"
     when a."Month_Start_Date"<e."Wholesale_Promo_End_Month" then "Month_End_Date"
     end as "Monthly_Wholesale_Promo_End_Date",
"Monthly_Wholesale_Promo_End_Date"-"Monthly_Wholesale_Promo_Start_Date"+1 as "Monthly_Wholesale_Promotion_Days",
e."Wholesale_Promo_Duration_Days"-("Monthly_Wholesale_Promo_End_Date"-e."Wholesale_Promo_Start_Date"+1) as "Wholesale_Promo_Remaining_Days",
round(100*"Wholesale_Promo_Remaining_Days"/e."Wholesale_Promo_Duration_Days",2) as "Wholesale_Promo_Remaining_Days_Portion",
e."Wholesale_Promo_Discount_Percentage"
from --BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
store_product_month a
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON a."Store_Code" = h."Store_Code"
--join edp_prod.pres."Dim_Customer" b
--on h."Site_Link_Code"=b."Site_Link_Code"
--and b."Distribution_Channel_Name"='WHOLESALE'
left join hist_dmnd_banner b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
--and b."Banner_Group_Code" is not null
--and upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK')
left join promo e
on b."Banner_Group_Code"=e."Mapped_Banner_Code"
and a."Product_Code"=e."Product_Code"
and (a."Month_Start_Date" between e."Wholesale_Promo_Start_Month" and e."Wholesale_Promo_End_Month")
)
,
retail_promo as (
select distinct 
a."Month_Start_Date",
dateadd('month',1,a."Month_Start_Date")-1 as "Month_End_Date",
--a."Demand_Group_Code",
b."Banner_Group_Code",
a."Product_Code",
e."Promotion_Brief_Detail_Key",
e."Retail_Promo_Start_Date",
e."Retail_Promo_End_Date",
e."Retail_Promo_Start_Month",
e."Retail_Promo_End_Month",
e."Retail_Promo_Duration_Days",
case when a."Month_Start_Date"=e."Retail_Promo_Start_Month" then e."Retail_Promo_Start_Date"
     when a."Month_Start_Date">e."Retail_Promo_Start_Month" then a."Month_Start_Date"
     end as "Monthly_Retail_Promo_Start_Date",
case when a."Month_Start_Date"=e."Retail_Promo_End_Month" then e."Retail_Promo_End_Date"
     when a."Month_Start_Date"<e."Retail_Promo_End_Month" then "Month_End_Date"
     end as "Monthly_Retail_Promo_End_Date",
"Monthly_Retail_Promo_End_Date"-"Monthly_Retail_Promo_Start_Date"+1 as "Monthly_Retail_Promotion_Days",
e."Retail_Promo_Duration_Days"-("Monthly_Retail_Promo_End_Date"-e."Retail_Promo_Start_Date"+1) as "Retail_Promo_Remaining_Days",
round(100*"Retail_Promo_Remaining_Days"/e."Retail_Promo_Duration_Days",2) as "Retail_Promo_Remaining_Days_Portion",
e."Retail_Promo_Discount_Percentage"
from --BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
store_product_month a
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON a."Store_Code" = h."Store_Code"
--join edp_prod.pres."Dim_Customer" b
--on h."Site_Link_Code"=b."Site_Link_Code"
--and b."Distribution_Channel_Name"='WHOLESALE'
left join hist_dmnd_banner b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
--and b."Banner_Group_Code" is not null
--and upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK')
left join promo e
on b."Banner_Group_Code"=e."Mapped_Banner_Code"
and a."Product_Code"=e."Product_Code"
and (a."Month_Start_Date" between e."Retail_Promo_Start_Month" and e."Retail_Promo_End_Month")
)
,
promo_summ as (
select 
"Month_Start_Date",
--"Banner_Group_Code",
"Store_Code",
"Product_Code",
min("Monthly_Wholesale_Promo_Start_Date") "Monthly_Wholesale_Promo_Start_Date_Min",
max("Monthly_Wholesale_Promo_End_Date") "Monthly_Wholesale_Promo_End_Date_Max",
min("Monthly_Retail_Promo_Start_Date") "Monthly_Retail_Promo_Start_Date_Min",
max("Monthly_Retail_Promo_End_Date") "Monthly_Retail_Promo_End_Date_Max"
from 
(
select distinct e."Store_Code",
a.*,
b."Retail_Promo_Start_Date",
b."Retail_Promo_End_Date",
b."Retail_Promo_Start_Month",
b."Retail_Promo_End_Month",
b."Retail_Promo_Duration_Days",
b."Monthly_Retail_Promo_Start_Date",
b."Monthly_Retail_Promo_End_Date",
b."Monthly_Retail_Promotion_Days",
b."Retail_Promo_Remaining_Days",
b."Retail_Promo_Remaining_Days_Portion",
b."Retail_Promo_Discount_Percentage"
from wholesale_promo a
left join retail_promo b
on a."Month_Start_Date"=b."Month_Start_Date"
--and a."Demand_Group_Code"=b."Demand_Group_Code"
and a."Banner_Group_Code"=b."Banner_Group_Code"
and a."Product_Code"=b."Product_Code"
and a."Promotion_Brief_Detail_Key"=b."Promotion_Brief_Detail_Key"
--join "EDP_PROD"."PRES"."Dim_Customer" d
--on --c."Demand_Group_Code"=d."Demand_Group_Code"
--a."Banner_Group_Code"=d."Banner_Group_Code"
--and d."Distribution_Channel_Name"='WHOLESALE'
--join edp_prod.pres."Dim_Customer_Retail_Store" h
--ON d."Site_Link_Code" = h."Site_Link_Code"
--join store_product_month e
--on h."Store_Code"=e."Store_Code"
join hist_dmnd_banner e
on a."Month_Start_Date"=e."Month_Start_Date"
--and a."Demand_Group_Code"=e."Demand_Group_Code"
and a."Banner_Group_Code"=e."Banner_Group_Code"
) 
group by all
)
,
final as (
select distinct
a."Month_Start_Date",
a."Store_Code",
--a."Store_State_Code",
a."Product_Code",
--b."Days_In_Month",
--b."Month_End_Date",
--nvl(d."Month_Holiday_Cnt",0) "Month_Holiday_Cnt",
--d."Month_First_Holiday_Date",
--d."Month_Last_Holiday_Date",
--d."Month_Holiday_DaysInBetween",
nvl(d."Next_Month_Holiday_Cnt",0) "Next_Month_Holiday_Cnt",
d."Next_Month_First_Holiday_Date",
--nvl(d."Previous_Month_Holiday_Cnt",0) "Previous_Month_Holiday_Cnt",
--d."Previous_Month_Last_Holiday_Date",
d."Days_to_Next_Month_First_Holiday",
--d."Days_from_Previous_Month_Last_Holiday",
case when e."Sigma_MCS_Days_In_Month" is not null then e."Sigma_MCS_Days_In_Month"
     else f."Sigma_State_MCS_Days_In_Month" end as "MCS_Days_In_Month",
case when e."Sigma_OOS_Days_In_Month" is not null then e."Sigma_OOS_Days_In_Month"
     else f."Sigma_State_OOS_Days_In_Month" end as "OOS_Days_In_Month",
round(100*"MCS_Days_In_Month"/b."Days_In_Month",2) as "MCS_Days_Percent_In_Month",
round(100*"OOS_Days_In_Month"/b."Days_In_Month",2) as "OOS_Days_Percent_In_Month",
ifnull(c."Monthly_Wholesale_Promo_End_Date_Max"-c."Monthly_Wholesale_Promo_Start_Date_Min"+1,0) as "Monthly_Wholesale_Promo_Days_Max",
ifnull(c."Monthly_Retail_Promo_End_Date_Max"-c."Monthly_Retail_Promo_Start_Date_Min"+1,0) as "Monthly_Retail_Promo_Days_Max",
LEAD("Monthly_Wholesale_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date") "Next_Month_Wholesale_Promotion_Days",
--Lag("Monthly_Wholesale_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code"  ORDER BY a."Month_Start_Date") "Previous_Month_Wholesale_Promotion_Days",
LEAD("Monthly_Retail_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code" ORDER BY a."Month_Start_Date") "Next_Month_Retail_Promotion_Days"
--,Lag("Monthly_Retail_Promo_Days_Max") OVER (PARTITION BY a."Store_Code",a."Product_Code"  ORDER BY a."Month_Start_Date") "Previous_Month_Retail_Promotion_Days",
from store_product_month a
join days_in_month b
on a."Month_Start_Date"=b."Month_Start_Date"
left join holidays d
on a."Month_Start_Date"=d."Month_Start_Date"
and a."Store_State_Code"=d."State"
left join promo_summ c
on a."Month_Start_Date"=c."Month_Start_Date"
and a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
left join plant_prod_avail e
on a."MAP_PLANT_CODE"=e."Plant_Code"
and a."Product_Code"=e."Product_Code"
and a."Month_Start_Date"=e."Month_Start_Date"
left join state_prod_avail f
on a."Store_State_Code"=f."Plant_State"
and a."Product_Code"=f."Product_Code"
and a."Month_Start_Date"=f."Month_Start_Date"
)
,
base as 
(select distinct 
"Store_Code",
"Product_Code",
"Month_Start_Date",
--"Monthly_Avg_Cost_Price",
"Monthly_Avg_Cost_Price_I",
"Monthly_Avg_Start_Price",
--"Monthly_Sigma_Avg_Nett_Price",
"Monthly_Sigma_Avg_Nett_Price_I",
--"Monthly_NonSigma_Avg_Nett_Price",
"Monthly_NonSigma_Avg_Nett_Price_I",
--"Monthly_Avg_Nett_Price",
"Monthly_Avg_Nett_Price_I",
--"Monthly_Avg_Discount",
"Monthly_Avg_Discount_I",
--"Monthly_Sigma_Avg_Margin",
"Monthly_Sigma_Avg_Margin_I",
--"Monthly_Avg_Margin",
"Monthly_Avg_Margin_I",
"Wholesale_Promo_Flag"
--,"Monthly_Store_Product_Order_Quantity",
--,"Monthly_Store_Product_Sigma_Order_Quantity",
--,"Monthly_Store_Product_NonSigma_Order_Quantity",
--,"Monthly_Wholesale_Promotion_Order_Quantity",
--,"Monthly_Sigma_Wholesale_Promotion_Order_Quantity",
--,"Monthly_NonSigma_Wholesale_Promotion_Order_Quantity"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT
WHERE "Month_Start_Date"<(select max("Month_Start_Date") from store_product_month) --dateadd('month',-1,(select max("Month_Start_Date") from store_product_month))
and "Month_Start_Date">=date('2021-09-01') --dateadd('month',-12,(select min("Month_Start_Date") from store_product_month))
)
,
cost_backward_impute as (
select 
"Store_Code",
"Product_Code",
"Month_Start_Date",
MAX_BY("Monthly_Avg_Cost_Price_I", "Recent_Month_Start_Date") "Monthly_Avg_Cost_Price_Impute"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
--c."Wholesale_Promo_Flag",
b."Month_Start_Date" as "Recent_Month_Start_Date",
b."Monthly_Avg_Cost_Price_I"
from store_product_month a
--join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT c
--on a."Store_Code"=c."Store_Code"
--and a."Product_Code"=c."Product_Code"
--and a."Month_Start_Date"=c."Month_Start_Date"
left join base b
on --a."Store_Code"=b."Store_Code"
--and 
a."Product_Code"=b."Product_Code"
and b."Month_Start_Date"<a."Month_Start_Date"
--and c."Wholesale_Promo_Flag"=b."Wholesale_Promo_Flag"
)
group by all
)
,
start_backward_impute as (
select 
"Store_Code",
"Product_Code",
"Month_Start_Date",
MAX_BY("Monthly_Avg_Start_Price", "Recent_Month_Start_Date") "Monthly_Avg_Start_Price_Impute"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
--c."Wholesale_Promo_Flag",
b."Month_Start_Date" as "Recent_Month_Start_Date",
b."Monthly_Avg_Start_Price"
from store_product_month a
--join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT c
--on a."Store_Code"=c."Store_Code"
--and a."Product_Code"=c."Product_Code"
--and a."Month_Start_Date"=c."Month_Start_Date"
left join base b
on --a."Store_Code"=b."Store_Code"
--and
a."Product_Code"=b."Product_Code"
and b."Month_Start_Date"<a."Month_Start_Date"
--and c."Wholesale_Promo_Flag"=b."Wholesale_Promo_Flag"
)
group by all
)
,
sigma_nett_backward_impute as (
select 
"Store_Code",
"Product_Code",
"Month_Start_Date",
MAX_BY("Monthly_Sigma_Avg_Nett_Price_I", "Recent_Month_Start_Date") "Monthly_Sigma_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
c."Wholesale_Promo_Flag",
b."Month_Start_Date" as "Recent_Month_Start_Date",
b."Monthly_Sigma_Avg_Nett_Price_I"
from store_product_month a
join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
left join base b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and b."Month_Start_Date"<a."Month_Start_Date"
and c."Wholesale_Promo_Flag"=b."Wholesale_Promo_Flag"
)
group by all
)
,
nonsigma_nett_backward_impute as (
select 
"Store_Code",
"Product_Code",
"Month_Start_Date",
MAX_BY("Monthly_NonSigma_Avg_Nett_Price_I", "Recent_Month_Start_Date") "Monthly_NonSigma_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
c."Wholesale_Promo_Flag",
b."Month_Start_Date" as "Recent_Month_Start_Date",
b."Monthly_NonSigma_Avg_Nett_Price_I"
from store_product_month a
join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
left join base b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and b."Month_Start_Date"<a."Month_Start_Date"
and c."Wholesale_Promo_Flag"=b."Wholesale_Promo_Flag"
)
group by all
)
,
nett_backward_impute as (
select 
"Store_Code",
"Product_Code",
"Month_Start_Date",
MAX_BY("Monthly_Avg_Nett_Price_I", "Recent_Month_Start_Date") "Monthly_Avg_Nett_Price_Impute"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
c."Wholesale_Promo_Flag",
b."Month_Start_Date" as "Recent_Month_Start_Date",
b."Monthly_Avg_Nett_Price_I"
from store_product_month a
join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
left join base b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and b."Month_Start_Date"<a."Month_Start_Date"
and c."Wholesale_Promo_Flag"=b."Wholesale_Promo_Flag"
)
group by all
)
,
hist as (
select
"Store_Code",
"Product_Code",
"Month_Start_Date",
min("Monthly_Avg_Discount_Impute") as "P12M_Min_Avg_Discount_I",
max("Monthly_Avg_Discount_Impute") as "P12M_Max_Avg_Discount_I",
min("Monthly_Avg_Margin_Impute") as "P12M_Min_Avg_Margin_I",
max("Monthly_Avg_Margin_Impute") as "P12M_Max_Avg_Margin_I",
min("Monthly_Sigma_Avg_Margin_Impute") as "P12M_Min_Sigma_Avg_Margin_I",
max("Monthly_Sigma_Avg_Margin_Impute") as "P12M_Max_Sigma_Avg_Margin_I"
from 
(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
b."Month_Start_Date" as "Recent_Month_Start_Date",
b."Monthly_Avg_Discount_I" as "Monthly_Avg_Discount_Impute" ,
b."Monthly_Avg_Margin_I" as "Monthly_Avg_Margin_Impute",
b."Monthly_Sigma_Avg_Margin_I" as "Monthly_Sigma_Avg_Margin_Impute"
from store_product_month a
left join base b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and b."Month_Start_Date"<a."Month_Start_Date"
)
group by all
)
,
price_summ as (
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
b."Monthly_Avg_Cost_Price_Impute" as "Monthly_Avg_Cost_Price_I",
e."Monthly_Avg_Start_Price_Impute" as "Monthly_Avg_Start_Price_I",
d."Monthly_Avg_Nett_Price_Impute" as "Monthly_Avg_Nett_Price_I",
f."Monthly_Sigma_Avg_Nett_Price_Impute" as "Monthly_Sigma_Avg_Nett_Price_I",
h."Monthly_NonSigma_Avg_Nett_Price_Impute" as "Monthly_NonSigma_Avg_Nett_Price_I",
round(100*("Monthly_Avg_Start_Price_I"-"Monthly_Avg_Nett_Price_I")/"Monthly_Avg_Start_Price_I",2) "Monthly_Avg_Discount_I",
round(100*("Monthly_Avg_Nett_Price_I"-"Monthly_Avg_Cost_Price_I")/"Monthly_Avg_Cost_Price_I",2) "Monthly_Avg_Margin_I",
round(100*("Monthly_Sigma_Avg_Nett_Price_I"-"Monthly_Avg_Cost_Price_I")/"Monthly_Avg_Cost_Price_I",2) "Monthly_Sigma_Avg_Margin_I",
CASE WHEN "Monthly_NonSigma_Avg_Nett_Price_I"<=0 AND "Monthly_Sigma_Avg_Nett_Price_I"<=0 THEN 0
      WHEN "Monthly_NonSigma_Avg_Nett_Price_I">0 AND "Monthly_Sigma_Avg_Nett_Price_I"<=0 THEN 1000
      ELSE round(100*("Monthly_NonSigma_Avg_Nett_Price_I"/"Monthly_Sigma_Avg_Nett_Price_I"-1),2) END AS "Monthly_Comp_Nett_Price_Index_I",
g."P12M_Min_Avg_Discount_I",
g."P12M_Max_Avg_Discount_I",
g."P12M_Min_Avg_Margin_I",
g."P12M_Max_Avg_Margin_I",
g."P12M_Min_Sigma_Avg_Margin_I",
g."P12M_Max_Sigma_Avg_Margin_I",
"Monthly_Avg_Discount_I"-"P12M_Max_Avg_Discount_I" as "Monthly_Diff_Max_Avg_Discount_I",
case when "Monthly_Avg_Discount_I"=0 and "P12M_Max_Avg_Discount_I"=0 then 0
      when "Monthly_Avg_Discount_I">0 and "P12M_Max_Avg_Discount_I"<=0 then 10000
      when "Monthly_Avg_Discount_I"<0 and "P12M_Max_Avg_Discount_I"=0 then -10000
      when "Monthly_Avg_Discount_I"<=0 and "P12M_Max_Avg_Discount_I"<0 then -round(100*"Monthly_Diff_Max_Avg_Discount_I"/"P12M_Max_Avg_Discount_I",1)
      else round(100*"Monthly_Diff_Max_Avg_Discount_I"/"P12M_Max_Avg_Discount_I",1) end as "Monthly_Index_Max_Avg_Discount_I",
"Monthly_Avg_Discount_I"-"P12M_Min_Avg_Discount_I" as "Monthly_Diff_Min_Avg_Discount_I",
case when "Monthly_Avg_Discount_I"=0 and "P12M_Min_Avg_Discount_I"=0 then 0
      when "Monthly_Avg_Discount_I">0 and "P12M_Min_Avg_Discount_I"<=0 then 10000
      when "Monthly_Avg_Discount_I"<0 and "P12M_Min_Avg_Discount_I"=0 then -10000
      when "Monthly_Avg_Discount_I"<=0 and "P12M_Min_Avg_Discount_I"<0 then -round(100*"Monthly_Diff_Min_Avg_Discount_I"/"P12M_Min_Avg_Discount_I",1)
      else round(100*"Monthly_Diff_Min_Avg_Discount_I"/"P12M_Min_Avg_Discount_I",1) end as "Monthly_Index_Min_Avg_Discount_I",
"Monthly_Avg_Margin_I"-"P12M_Max_Avg_Margin_I" as "Monthly_Diff_Max_Avg_Margin_I",
case when "Monthly_Avg_Margin_I"=0 and "P12M_Max_Avg_Margin_I"=0 then 0
      when "Monthly_Avg_Margin_I">0 and "P12M_Max_Avg_Margin_I"<=0 then 10000
      when "Monthly_Avg_Margin_I"<0 and "P12M_Max_Avg_Margin_I"=0 then -10000
      when "Monthly_Avg_Margin_I"<=0 and "P12M_Max_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Max_Avg_Margin_I"/"P12M_Max_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Max_Avg_Margin_I"/"P12M_Max_Avg_Margin_I",1) end as "Monthly_Index_Max_Avg_Margin_I",
"Monthly_Avg_Margin_I"-"P12M_Min_Avg_Margin_I" as "Monthly_Diff_Min_Avg_Margin_I",
case when "Monthly_Avg_Margin_I"=0 and "P12M_Min_Avg_Margin_I"=0 then 0
      when "Monthly_Avg_Margin_I">0 and "P12M_Min_Avg_Margin_I"<=0 then 10000
      when "Monthly_Avg_Margin_I"<0 and "P12M_Min_Avg_Margin_I"=0 then -10000
      when "Monthly_Avg_Margin_I"<=0 and "P12M_Min_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Min_Avg_Margin_I"/"P12M_Min_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Min_Avg_Margin_I"/"P12M_Min_Avg_Margin_I",1) end as "Monthly_Index_Min_Avg_Margin_I",
"Monthly_Sigma_Avg_Margin_I"-"P12M_Max_Sigma_Avg_Margin_I" as "Monthly_Diff_Max_Sigma_Avg_Margin_I",
case when "Monthly_Sigma_Avg_Margin_I"=0 and "P12M_Max_Sigma_Avg_Margin_I"=0 then 0
      when "Monthly_Sigma_Avg_Margin_I">0 and "P12M_Max_Sigma_Avg_Margin_I"<=0 then 10000
      when "Monthly_Sigma_Avg_Margin_I"<0 and "P12M_Max_Sigma_Avg_Margin_I"=0 then -10000
      when "Monthly_Sigma_Avg_Margin_I"<=0 and "P12M_Max_Sigma_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Max_Sigma_Avg_Margin_I"/"P12M_Max_Sigma_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Max_Sigma_Avg_Margin_I"/"P12M_Max_Sigma_Avg_Margin_I",1) end as "Monthly_Index_Max_Sigma_Avg_Margin_I",
"Monthly_Sigma_Avg_Margin_I"-"P12M_Min_Sigma_Avg_Margin_I" as "Monthly_Diff_Min_Sigma_Avg_Margin_I",
case when "Monthly_Sigma_Avg_Margin_I"=0 and "P12M_Min_Sigma_Avg_Margin_I"=0 then 0
      when "Monthly_Sigma_Avg_Margin_I">0 and "P12M_Min_Sigma_Avg_Margin_I"<=0 then 10000
      when "Monthly_Sigma_Avg_Margin_I"<0 and "P12M_Min_Sigma_Avg_Margin_I"=0 then -10000
      when "Monthly_Sigma_Avg_Margin_I"<=0 and "P12M_Min_Sigma_Avg_Margin_I"<0 then -round(100*"Monthly_Diff_Min_Sigma_Avg_Margin_I"/"P12M_Min_Sigma_Avg_Margin_I",1)
      else round(100*"Monthly_Diff_Min_Sigma_Avg_Margin_I"/"P12M_Min_Sigma_Avg_Margin_I",1) end as "Monthly_Index_Min_Sigma_Avg_Margin_I"
from store_product_month a
left join cost_backward_impute b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
left join nett_backward_impute d
on a."Month_Start_Date"=d."Month_Start_Date"
and a."Store_Code"=d."Store_Code"
and a."Product_Code"=d."Product_Code"
left join sigma_nett_backward_impute f
on a."Month_Start_Date"=f."Month_Start_Date"
and a."Store_Code"=f."Store_Code"
and a."Product_Code"=f."Product_Code"
left join nonsigma_nett_backward_impute h
on a."Month_Start_Date"=h."Month_Start_Date"
and a."Store_Code"=h."Store_Code"
and a."Product_Code"=h."Product_Code"
left join start_backward_impute e
on a."Month_Start_Date"=e."Month_Start_Date"
and a."Store_Code"=e."Store_Code"
and a."Product_Code"=e."Product_Code"
left join hist g
on a."Month_Start_Date"=g."Month_Start_Date"
and a."Store_Code"=g."Store_Code"
and a."Product_Code"=g."Product_Code"
)


select distinct 
a."Month_Start_Date",
a."Store_Code",
--a."Store_State_Code",
a."Product_Code",
a."Next_Month_Holiday_Cnt",
a."Next_Month_First_Holiday_Date",
a."Days_to_Next_Month_First_Holiday",
a."MCS_Days_In_Month",
a."OOS_Days_In_Month",
a."MCS_Days_Percent_In_Month",
a."OOS_Days_Percent_In_Month",
a."Next_Month_Wholesale_Promotion_Days",
a."Next_Month_Retail_Promotion_Days",
b.* exclude ("Store_Code","Product_Code","Month_Start_Date"
)
,current_date() as "Insertion_Date"
from final a
left join price_summ b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
where a."Month_Start_Date"<=(select max("Month_Start_Date") as "Month_Start_Date" from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE)
) 
;