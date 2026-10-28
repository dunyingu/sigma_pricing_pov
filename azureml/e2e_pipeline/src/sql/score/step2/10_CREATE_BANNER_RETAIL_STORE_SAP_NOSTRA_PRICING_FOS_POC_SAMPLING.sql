create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SAMPLING AS (
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SAMPLING_VW AS (
with store_product_month as 
(select distinct 
a."Store_Code",
a."Store_State_Code",
a."Product_Code",
b."MAP_PLANT_CODE",
c."Month_Start_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG a 
cross join (select *
from 
(--select date('2024-07-01') as "Month_Start_Date"
SELECT MAX("Month_Start_Date") as "Month_Start_Date" from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG
union
--select date('2024-08-01') as "Month_Start_Date"
SELECT dateadd('month',1,MAX("Month_Start_Date")) as "Month_Start_Date" from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG
)
) c
join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
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
and (--date('2024-07-01') between "Wholesale_Promo_Start_Month" and "Wholesale_Promo_End_Month"
--or 
--date('2024-08-01') between "Wholesale_Promo_Start_Month" and "Wholesale_Promo_End_Month"
--or
--date('2024-09-01') between "Wholesale_Promo_Start_Month" and "Wholesale_Promo_End_Month"

(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG) between "Wholesale_Promo_Start_Month" and "Wholesale_Promo_End_Month"
or
(SELECT dateadd('month',1,MAX("Month_Start_Date")) from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG) between "Wholesale_Promo_Start_Month" and "Wholesale_Promo_End_Month"
)
)
,
plant_prod_avail as (
select distinct 
b."Plant_State",
a."Plant_Code",
right(a."Product_Code",8) "Product_Code",
c."Month_Start_Date",
date(a."MCS_ETA_Date") "MCS_ETA_Date",
a."Planned_Delivery_Days",
case when c."Month_Start_Date"<=date(a."MCS_ETA_Date") then date(a."MCS_ETA_Date")-c."Month_Start_Date"+1
           when c."Month_Start_Date">date(a."MCS_ETA_Date") then 0
           else 0 end as "Sigma_MCS_Days_In_Month",
case when c."Month_Start_Date"<=date(a."MCS_ETA_Date") then date(a."MCS_ETA_Date")-c."Month_Start_Date"+1
           when c."Month_Start_Date">date(a."MCS_ETA_Date") then 0
           else 0 end as "Sigma_OOS_Days_In_Month"
from edp_prod.pres."Dim_Product_Plant_Attribute" a
cross join (select distinct "Month_Start_Date" from store_product_month) c
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
oos as (
select 
a.*,
case when e."Sigma_MCS_Days_In_Month" is not null then e."Sigma_MCS_Days_In_Month"
     else f."Sigma_State_MCS_Days_In_Month" end as "MCS_Days_In_Month",
case when e."Sigma_OOS_Days_In_Month" is not null then e."Sigma_OOS_Days_In_Month"
     else f."Sigma_State_OOS_Days_In_Month" end as "OOS_Days_In_Month",
from store_product_month a
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
pov_scope as (
select 
distinct *
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM
where concat("Store_Code",'_',"Product_Code") not in 
(select 
distinct concat("Store_Code",'_',"Product_Code")
from 
(
(select distinct 
a."Store_Code",
--b."Banner_Group_Code",
a."Product_Code"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG a
left join edp_prod.pres."Dim_Customer_Retail_Store" h
ON a."Store_Code" = h."Store_Code"
left join edp_prod.pres."Dim_Customer" b
on h."Site_Link_Code"=b."Site_Link_Code"
--and b."Banner_Group_Code" is not null
--and upper(b."Banner_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK')
inner join promo e
on b."Banner_Group_Code"=e."Mapped_Banner_Code"
and a."Product_Code"=e."Product_Code")
union
(select distinct a."Store_Code",a."Product_Code" from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_KIA_FEAT a
inner join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and (a."Monthly_Avg_Cost_Price_I" is null or a."Monthly_Avg_Nett_Price_I" is null)
)
union 
(select distinct "Store_Code","Product_Code" from oos
where "MCS_Days_In_Month">0 or "OOS_Days_In_Month">0
)
)
)
)
,
sales_invoice as (
select 
--c."Customer_Retail_Store_Key",
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
--c."Order_Date",
--c."Order_Month_Start_Date" as "Month_Start_Date",
--c."Plant_Key",
count(distinct c."Order_Document_Number") "Order_Cnt",
--round(sum("c.Cost_Price"*c."Order_Quantity")/sum(c."Order_Quantity"),2) as "Monthly_Sigma_Avg_Cost_Price_Invoice",
--c."Start_Price",
--round(sum(c."Nett_Price"*c."Order_Quantity")/sum(c."Order_Quantity"),2) as "Monthly_Sigma_Avg_Nett_Price_Invoice",
sum(ifnull(c."Order_Quantity",0)) as "Monthly_Store_Product_Sigma_Order_Quantity",
--round(sum(ifnull(c."Nett_Price"*c."Order_Quantity",0)),2) as "Monthly_Sigma_Sales_Order_Revenue",
--round(sum(ifnull(c."Revenue",0)),2) as "Monthly_Sigma_Sales_Order_Revenue",
sum(ifnull(c."Revenue",0)) as "Monthly_Sigma_Sales_Order_Revenue",
--round(sum(ifnull(c."COGS_Amount",0)),2) as "Monthly_Sigma_COGS",
sum(ifnull(c."COGS_Amount",0)) as "Monthly_Sigma_COGS",
"Monthly_Sigma_Sales_Order_Revenue"-"Monthly_Sigma_COGS" as "Monthly_Sigma_GP" 
--,c."Promotion_Brief_Detail_Key",
--'SIGMA' AS "Supplier_Master_Type_Name"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT a
left join
(
SELECT DISTINCT 
e."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Key",
RIGHT(d."Product_Code",8) "Product_Code",
a."Order_Document_Number",
a."Order_Document_Line_Item_Number",
a."Order_Date_Key",
Date(a."Order_Date_Key",'YYYYMMDD') "Order_Date",
date_trunc('month',"Order_Date") "Order_Month_Start_Date",
a."Plant_Key",
a."Cost_Price",
a."Start_Price",
a."Nett_Price",
--round(a."Invoice_Quantity",0) "Order_Quantity",
round(a."Invoice_Quantity_Base_Unit",0) "Order_Quantity",
round(a."Nett_Price"*a."Invoice_Quantity_Base_Unit",2) "Revenue",
round(a."COGS_Amount",2) "COGS_Amount",
a."Promotion_Brief_Detail_Key"
FROM "EDP_PROD"."PRES"."Fact_Sales_Invoice" a
--EDP_ANALYTICS_SANDPIT.pres."Fact_Sales_Order_Full" a
left JOIN edp_prod.pres."Dim_Customer" f
ON a."Sold_To_Customer_Key"=f."Customer_Key"
and f."Customer_Key">0 
and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Customer_Retail_Store" e
on f."Site_Link_Code" = e."Site_Link_Code"
left JOIN "EDP_PROD"."PRES"."Dim_Product" d
ON a."Product_Key" = d."Product_Key"
and d."Product_Key">0
and UPPER(d."Product_Name") NOT LIKE '%COVID%'
where a."Sold_To_Customer_Key">0
and e."Customer_Retail_Store_Key" is not null --and e."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
--and a."Sold_To_Customer_Key" in (select distinct "Customer_Key" from "EDP_PROD"."PRES"."Fact_Retail_Wholesale_Order"
--where "Customer_Key">0
--)
and e."Customer_Retail_Store_Key" in (select distinct "Customer_Retail_Store_Key" from "EDP_PROD"."PRES"."Fact_Retail_Wholesale_Order" 
     --where "Customer_Key">0
     )
and a."Product_Key">0
and d."Product_Code" is not null and d."Product_Code"!='N/A'
and d."Product_Code"!='NA' and d."Product_Code"!='UKN'
and a."Plant_Key">0
and a."Cost_Price">0
and a."Start_Price">0
and a."Start_Price">=a."Cost_Price"
and a."Nett_Price">0
and a."Nett_Price"<=a."Start_Price"
and a."Nett_Price">=a."Cost_Price"
and "Order_Quantity">=1
--and concat(e."Store_Code",'_',RIGHT(d."Product_Code",8)) in (select distinct concat("Store_Code",'_',"Product_Code") from pov_scope)
--and "Order_Month_Start_Date" >=dateadd('month',-12,(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG))
--and "Order_Month_Start_Date" < (SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
) c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and a."Month_Start_Date"=c."Order_Month_Start_Date"
where a."Month_Start_Date">=dateadd('month',-12,(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG))
and a."Month_Start_Date"<(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and concat(a."Store_Code",'_',a."Product_Code") in (select distinct concat("Store_Code",'_',"Product_Code")
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA_POC
--pov_scope
where "Material_Group_1_Code" in ('FOS','OTC')
)
group by all
)
,
sales_invoice_summ as (
select 
"Store_Code",
"Product_Code",
sum("Order_Cnt") "Order_Cnt",
round(avg("Monthly_Store_Product_Sigma_Order_Quantity"),0) "Monthly_Store_Product_Sigma_Order_Quantity_Avg",
round(stddev("Monthly_Store_Product_Sigma_Order_Quantity"),0) "Monthly_Store_Product_Sigma_Order_Quantity_Stddev",
round(avg("Monthly_Sigma_Sales_Order_Revenue"),2) "Monthly_Sigma_Sales_Order_Revenue_Avg",
round(stddev("Monthly_Sigma_Sales_Order_Revenue"),2) "Monthly_Sigma_Sales_Order_Revenue_Stddev",
round(avg("Monthly_Sigma_COGS"),2) "Monthly_Sigma_COGS_Avg",
round(stddev("Monthly_Sigma_COGS"),2) "Monthly_Sigma_COGS_Stddev",
round(avg("Monthly_Sigma_GP"),2) "Monthly_Sigma_GP_Avg",
round(stddev("Monthly_Sigma_GP"),2) "Monthly_Sigma_GP_Stddev"
from sales_invoice
--where "Monthly_Store_Product_Sigma_Order_Quantity">0
group by all
)
,
gp_percentile as (
select distinct 
"Store_Code",
"Product_Code",
"Monthly_Sigma_GP_Avg",
"Monthly_Sigma_GP_Stddev",
percentile_cont(0.25) within group(order by "Monthly_Sigma_GP_Avg") over () as "Monthly_Sigma_GP_Avg_P25",
percentile_cont(0.5) within group(order by "Monthly_Sigma_GP_Avg") over () as "Monthly_Sigma_GP_Avg_Med",
percentile_cont(0.75) within group(order by "Monthly_Sigma_GP_Avg") over () as "Monthly_Sigma_GP_Avg_P75",
percentile_cont(0.25) within group(order by "Monthly_Sigma_GP_Stddev") over () as "Monthly_Sigma_GP_Stddev_P25",
percentile_cont(0.5) within group(order by "Monthly_Sigma_GP_Stddev") over () as "Monthly_Sigma_GP_Stddev_Med",
percentile_cont(0.75) within group(order by "Monthly_Sigma_GP_Stddev") over () as "Monthly_Sigma_GP_Stddev_P75"
from sales_invoice_summ
)
,
gp_bucket as (
select distinct 
a."Store_Code",
a."Product_Code",
a."Monthly_Sigma_GP_Avg",
case when a."Monthly_Sigma_GP_Avg"<b."Monthly_Sigma_GP_Avg_P25" then 'GP_Q1'
     when a."Monthly_Sigma_GP_Avg">=b."Monthly_Sigma_GP_Avg_P25" and a."Monthly_Sigma_GP_Avg"<b."Monthly_Sigma_GP_Avg_Med" then 'GP_Q2'
     when a."Monthly_Sigma_GP_Avg">=b."Monthly_Sigma_GP_Avg_Med" and a."Monthly_Sigma_GP_Avg"<b."Monthly_Sigma_GP_Avg_P75" then 'GP_Q3'
     when a."Monthly_Sigma_GP_Avg">=b."Monthly_Sigma_GP_Avg_P75" then 'GP_Q4' end as "GP_Bucket"
from sales_invoice_summ a
join gp_percentile b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
)
,
propensity_bucket as (
select distinct
a."Store_Code",
a."Product_Code",
a."Monthly_Store_Product_Order_Propensity",
percentile_cont(0.25) within group(order by a."Monthly_Store_Product_Order_Propensity") over () as"Monthly_Store_Product_Order_Propensity_P25",
percentile_cont(0.5) within group(order by a."Monthly_Store_Product_Order_Propensity") over () as "Monthly_Store_Product_Order_Propensity_Med",
percentile_cont(0.75) within group(order by a."Monthly_Store_Product_Order_Propensity") over () as "Monthly_Store_Product_Order_Propensity_P75",
case when a."Monthly_Store_Product_Order_Propensity"<"Monthly_Store_Product_Order_Propensity_P25" then 'Propensity_Q1'
     when a."Monthly_Store_Product_Order_Propensity">="Monthly_Store_Product_Order_Propensity_P25" and a."Monthly_Store_Product_Order_Propensity"<"Monthly_Store_Product_Order_Propensity_Med" then 'Propensity_Q2'
     when a."Monthly_Store_Product_Order_Propensity">="Monthly_Store_Product_Order_Propensity_Med" and a."Monthly_Store_Product_Order_Propensity"<"Monthly_Store_Product_Order_Propensity_P75" then 'Propensity_Q3'
     when a."Monthly_Store_Product_Order_Propensity">="Monthly_Store_Product_Order_Propensity_P75" then 'Propensity_Q4' end as "Propensity_Bucket"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE a
--inner join pov_scope b
--on a."Store_Code"=b."Store_Code"
--and a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and a."Price_Change_Level"=1
--and a."Monthly_Store_Product_Order_Label_Pred"=1
and a."Monthly_Store_Product_Order_Propensity">=0.46 --0.47
and a."Monthly_Avg_Margin_I">0
)
,
/*
product_percentile as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
percentile_cont(0.25) within group(order by a."P12M_Compliance") over (partition by a."Product_Code") as "Compliance_P25",
percentile_cont(0.75) within group(order by a."P12M_Compliance") over (partition by a."Product_Code") as "Compliance_P75",
percentile_cont(0.25) within group(order by a."Price_Qty_Percent_Change") over (partition by a."Product_Code") as "Sensitivity_P25",
percentile_cont(0.75) within group(order by a."Price_Qty_Percent_Change") over (partition by a."Product_Code") as "Sensitivity_P75"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
)
,
product_hchs as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'hchs' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join product_percentile b
on --a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and a."P12M_Compliance">=b."Compliance_P75"
and a."Price_Qty_Percent_Change">b."Sensitivity_P75"
)
,
product_hcls as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'hcls' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join product_percentile b
on --a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and a."P12M_Compliance">=b."Compliance_P75"
and a."Price_Qty_Percent_Change"<=b."Sensitivity_P25"
)
,
product_lchs as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'lchs' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join product_percentile b
on --a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and a."P12M_Compliance"<b."Compliance_P25"
and a."Price_Qty_Percent_Change">b."Sensitivity_P75"
)
,
product_lcls as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'lcls' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join product_percentile b
on --a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
and a."P12M_Compliance"<b."Compliance_P25"
and a."Price_Qty_Percent_Change"<=b."Sensitivity_P25"
)
,
product_zones as ( 
--select a.* 
--a."Zone",
--count(a.*)
--from 
--(
select distinct *
from 
(select distinct * from product_hchs)
union
(select distinct * from product_hcls)
union
(select distinct * from product_lchs)
union
(select distinct * from product_lcls)
) --a
--inner join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE c
--on a."Store_Code"=c."Store_Code"
--and a."Product_Code"=c."Product_Code"
--and c."Price_Change_Level"=1
--and c."Monthly_Store_Product_Order_Label_Pred"=1
--and c."Monthly_Store_Product_Order_Propensity">=0.47
--and c."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
--group by 1
--)
,
product_zone_cnt as 
(
select *
from 
(
select 
a."Product_Code",
a."Zone",
count(distinct a."Store_Code") "Store_Cnt"
from product_zones a
group by all
)
where "Store_Cnt">1
)
,
*/
percentile as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
percentile_cont(0.25) within group(order by a."P12M_Compliance") over () as "Compliance_P25",
percentile_cont(0.5) within group(order by a."P12M_Compliance") over () as "Compliance_P50",
percentile_cont(0.75) within group(order by a."P12M_Compliance") over () as "Compliance_P75",
percentile_cont(0.25) within group(order by a."Price_Qty_Percent_Change") over () as "Sensitivity_P25",
percentile_cont(0.5) within group(order by a."Price_Qty_Percent_Change") over () as "Sensitivity_P50",
percentile_cont(0.75) within group(order by a."Price_Qty_Percent_Change") over () as "Sensitivity_P75"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
--inner join pov_scope b
--on a."Store_Code"=b."Store_Code"
--and a."Product_Code"=b."Product_Code"
--inner join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE c
--on b."Store_Code"=c."Store_Code"
--and b."Product_Code"=c."Product_Code"
--and c."Price_Change_Level"=1
--and c."Monthly_Store_Product_Order_Label_Pred"=1
--and c."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
)
,
hchs as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'hchs' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join percentile b
on a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
--and a."P12M_Compliance">=b."Compliance_P75"
--and a."Price_Qty_Percent_Change">b."Sensitivity_P75"
and a."P12M_Compliance">=b."Compliance_P50"
and a."Price_Qty_Percent_Change">b."Sensitivity_P50"
)
,
hcls as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'hcls' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join percentile b
on a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
--and a."P12M_Compliance">=b."Compliance_P75"
--and a."Price_Qty_Percent_Change"<=b."Sensitivity_P25"
and a."P12M_Compliance">=b."Compliance_P50"
and a."Price_Qty_Percent_Change"<=b."Sensitivity_P50"
)
,
lchs as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'lchs' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join percentile b
on a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
--and a."P12M_Compliance"<b."Compliance_P25"
--and a."Price_Qty_Percent_Change">b."Sensitivity_P75"
and a."P12M_Compliance"<b."Compliance_P50"
and a."Price_Qty_Percent_Change">b."Sensitivity_P50"
)
,
lcls as (
select distinct 
a."Store_Code",
a."Product_Code",
a."P12M_Compliance",
a."Price_Qty_Percent_Change",
b."Compliance_P25",
b."Compliance_P75",
b."Sensitivity_P25",
b."Sensitivity_P75",
'lcls' as "Zone"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
join percentile b
on a."Store_Code"=b."Store_Code" and 
a."Product_Code"=b."Product_Code"
where a."Month_Start_Date"=(SELECT MAX("Month_Start_Date") from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG)
--and a."P12M_Compliance"<b."Compliance_P25"
--and a."Price_Qty_Percent_Change"<=b."Sensitivity_P25"
and a."P12M_Compliance"<b."Compliance_P50"
and a."Price_Qty_Percent_Change"<=b."Sensitivity_P50"
)
,
zones as ( 
select distinct *
from 
(select distinct * from hchs)
union
(select distinct * from hcls)
union
(select distinct * from lchs)
union
(select distinct * from lcls)
)

select distinct 
a.*,
d.* exclude("Store_Code","Product_Code"),
b."Monthly_Sigma_GP_Avg",
b."GP_Bucket",
c."Monthly_Store_Product_Order_Propensity",
c."Propensity_Bucket",
concat(a."Zone",'_',b."GP_Bucket",'_',c."Propensity_Bucket") "Strat"
,current_date() as "Insertion_Date"
from zones a
inner join gp_bucket b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
inner join propensity_bucket c 
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
inner join pov_scope d 
on a."Store_Code"=d."Store_Code"
and a."Product_Code"=d."Product_Code"
)
;