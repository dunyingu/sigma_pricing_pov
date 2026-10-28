CREATE OR REPLACE TABLE BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA AS 
--CREATE OR REPLACE VIEW BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA_VW  AS 
(
with base as 
(
select *
from 
(
select --distinct
"Customer_Retail_Store_Key",
"Store_Code",
"Product_Code_Short" as "Product_Code",
"Invoice_Date" as "Order_Date",
"Invoice_Month_Start_Date" as "Order_Month_Start_Date",
"Plant_Key",
null as "Stock_Condition_Key",
null as "Order_Rejection_Reason_Key",
"Sigma_Cost_Price" as "Cost_Price",
null as "Start_Price",
"Invoice_Price" as "Nett_Price",
"Invoice_Quantity" as "Order_Quantity",
null as "Availability_Opportunity_Quantity",
"Promotion_Brief_Detail_Key",
"Supplier_Master_Type_Name"
from 
(
select 
distinct 
a."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Retail_Master_Key",
RIGHT(c."Product_Code",8) "Product_Code_Short",
a."Wholesale_Order_ID",
a."Invoice_Number",
a."Invoice_Date_Key",
date(a."Invoice_Date_Key",'yyyymmdd') "Invoice_Date",
date_trunc('month',"Invoice_Date") "Invoice_Month_Start_Date",
a."Plant_Key",
case when g."Daily_Cost_Price" is not null then g."Daily_Cost_Price"
     else h."Standard_Price" end as "Sigma_Cost_Price",
CASE WHEN g."Daily_Cost_Price" is not NULL THEN "Invoice_Date"-g."Order_Date"
	 ELSE "Invoice_Date" - date(h."ETL_ROW_EFFECTIVE_DATE") END AS "Cost_Price_Effective_Days",
a."Invoice_Price",
round(a."Invoice_Quantity",0) "Invoice_Quantity",
a."Invoice_Net_Amount",
a."Promotion_Brief_Detail_Key",
a."Supplier_Master_Type_Name"
from "EDP_PROD"."PRES"."Fact_Retail_Wholesale_Order" a
left join edp_prod.pres."Dim_Customer_Retail_Store" e
ON a."Customer_Retail_Store_Key" = e."Customer_Retail_Store_Key"
--left JOIN edp_prod.pres."Dim_Customer" f
--ON e."Site_Link_Code" = f."Site_Link_Code"
--and a."Customer_Key"=f."Customer_Key"
--and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Product_Retail_Master" b
on a."Product_Retail_Master_Key" = b."Product_Retail_Master_Key"
left JOIN edp_prod.pres."Dim_Product" c
ON b."Primary_Wholesale_Product_Key"=c."Product_Key"
AND c."Product_Key">0
and UPPER(c."Product_Name") NOT LIKE '%COVID%'
left join 
(
select distinct 
"Product_Code","Order_Date"
,LEAD("Order_Date") OVER (PARTITION BY "Product_Code" ORDER BY "Order_Date") "Next_Order_Date"
,"Daily_Cost_Price"
from 
(
SELECT DISTINCT 
--a."Product_Key",
RIGHT(d."Product_Code",8) "Product_Code",
--a."Order_Date_Key",
Date(a."Order_Date_Key",'YYYYMMDD') "Order_Date",
sum(a."Cost_Price"*a."Order_Quantity_Base_Unit")/sum(a."Order_Quantity_Base_Unit") "Daily_Cost_Price"
FROM "EDP_PROD"."PRES"."Fact_Sales_Order" a
--EDP_ANALYTICS_SANDPIT.pres."Fact_Sales_Order_Full" a
JOIN "EDP_PROD"."PRES"."Dim_Product" d
ON a."Product_Key" = d."Product_Key"
and d."Product_Key">0
where a."Order_Quantity_Base_Unit">0 and 
a."Cost_Price">0 and 
d."Product_Code" is not null and d."Product_Code"!='N/A'
and d."Product_Code"!='NA' and d."Product_Code"!='UKN'
group by 1,2
)
) g
on right(c."Product_Code",8)=g."Product_Code"
and date(a."Invoice_Date_Key",'yyyymmdd')>=date(g."Order_Date") 
and date(a."Invoice_Date_Key",'yyyymmdd')<date(g."Next_Order_Date")
left join 
(select distinct "Material","StandardPrice","MaterialPriceUnitQty",
"StandardPrice"/"MaterialPriceUnitQty" as "Standard_Price",
"ETL_ROW_EFFECTIVE_DATE","ETL_ROW_EXPIRY_DATE"
from 
(select *,
Row_Number() OVER (PARTITION BY "Material","ETL_ROW_EFFECTIVE_DATE","ETL_ROW_EXPIRY_DATE" ORDER BY "CostEstimate"  DESC) "MaterialRank"
from edp_prod.STG.SAP_FACTSOFZSPYMATVALNPRICE --standardprice -> cost_price
where "StandardPrice">0
)
where "MaterialRank"=1
) h
on c."Product_Code"=h."Material"
and date(a."Invoice_Date_Key",'yyyymmdd')>=date(h."ETL_ROW_EFFECTIVE_DATE") 
and date(a."Invoice_Date_Key",'yyyymmdd')<date(h."ETL_ROW_EXPIRY_DATE")
where a."Customer_Retail_Store_Key" is not null --and a."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
--and a."Customer_Key">0
and c."Product_Code" is not null and c."Product_Code"!='N/A'
and c."Product_Code"!='NA' and c."Product_Code"!='UKN'
and a."Invoice_Price">0
and a."Invoice_Quantity">=1
and a."Supplier_Master_Type_Name"='WHOLESALERS'--a."Supplier_Master_Type_Name"!='SIGMA'
--and a."Main_Leakage_Reason"!='Not Ranged'
and --date(a."Invoice_Date_Key",'yyyymmdd') >=date('2019-10-01')
date(a."Invoice_Date_Key",'yyyymmdd') >=date('2021-08-27')
--and date(a."Invoice_Date_Key",'yyyymmdd') <=date('2023-08-31')
and date(a."Invoice_Date_Key",'yyyymmdd') <=Current_Date()
QUALIFY Row_Number() OVER (PARTITION BY 
a."Customer_Retail_Store_Key",
e."Store_Code",
a."Product_Retail_Master_Key",
"Product_Code_Short",
a."Wholesale_Order_ID",
a."Invoice_Number",
a."Invoice_Date_Key",
a."Plant_Key",
a."Promotion_Brief_Detail_Key",
a."Supplier_Master_Type_Name"
ORDER BY "Cost_Price_Effective_Days")=1
)
union
select --distinct
"Customer_Retail_Store_Key",
"Store_Code",
"Product_Code",
"Order_Date",
"Order_Month_Start_Date",
"Plant_Key",
"Stock_Condition_Key",
"Order_Rejection_Reason_Key",
"Cost_Price",
"Start_Price",
"Nett_Price",
"Order_Quantity_Base_Unit" as "Order_Quantity",
"Availability_Opportunity_Quantity",
"Promotion_Brief_Detail_Key",
'SIGMA' AS "Supplier_Master_Type_Name"
from 
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
a."Stock_Condition_Key",
a."Order_Rejection_Reason_Key",
a."Cost_Price",
a."Start_Price",
a."Nett_Price",
round(a."Order_Quantity",0) "Order_Quantity",
round(a."Order_Quantity_Base_Unit",0) "Order_Quantity_Base_Unit",
a."Availability_Opportunity_Quantity",
a."Promotion_Brief_Detail_Key"
FROM "EDP_PROD"."PRES"."Fact_Sales_Order" a
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
and a."Order_Quantity">=1
and a."Order_Quantity_Base_Unit">=1
and --"Order_Date" >=date('2019-10-01')
"Order_Date" >=date('2021-08-27')
--and "Order_Date" <=date('2023-08-31')
and "Order_Date" <=Current_Date()
)
)
)
,
order_hist as (
select *
from 
(
select --distinct
a."Customer_Retail_Store_Key",
a."Store_Code",
a."Product_Code",
a."Order_Date",
a."Order_Month_Start_Date",
a."Plant_Key",
a."Stock_Condition_Key",
a."Order_Rejection_Reason_Key",
b."Cost_Price",
a."Start_Price",
a."Nett_Price",
a."Order_Quantity",
a."Availability_Opportunity_Quantity",
a."Promotion_Brief_Detail_Key",
a."Supplier_Master_Type_Name"
from 
(select --distinct
* exclude ("Cost_Price")
from base
where "Cost_Price" is null) a
left join
(
select --distinct
*
from base
where "Cost_Price" is not null 
qualify row_number() over (partition by "Product_Code" order by "Order_Date")=1
) b
on a."Product_Code"=b."Product_Code"
union
select --distinct 
*
from base
where "Cost_Price" is not null 
)
--where "Cost_Price" is not null
)
,
min_max_med as (
select 
"Store_Code",
"Product_Code",
min("Cost_Price") "Cost_Price_Min",
max("Cost_Price") "Cost_Price_Max",
median("Cost_Price") "Cost_Price_Med",
avg("Cost_Price") "Cost_Price_Mean",
nvl(stddev("Cost_Price"),0) "Cost_Price_Stdev",
min("Start_Price") "Start_Price_Min",
max("Start_Price") "Start_Price_Max",
median("Start_Price") "Start_Price_Med",
avg("Start_Price") "Start_Price_Mean",
nvl(stddev("Start_Price"),0) "Start_Price_Stdev",
min("Nett_Price") "Nett_Price_Min",
max("Nett_Price") "Nett_Price_Max",
median("Nett_Price") "Nett_Price_Med",
avg("Nett_Price") "Nett_Price_Mean",
nvl(stddev("Nett_Price"),0) "Nett_Price_Stdev",
min("Order_Quantity") "Order_Quantity_Min",
max("Order_Quantity") "Order_Quantity_Max",
median("Order_Quantity") "Order_Quantity_Med",
avg("Order_Quantity") "Order_Quantity_Mean",
nvl(stddev("Order_Quantity"),0) "Order_Quantity_Stdev"
from order_hist
group by 1,2
)
,
percentile as (
select distinct
"Store_Code",
"Product_Code",
percentile_cont(0.25) within group(order by "Cost_Price") over (partition by "Store_Code","Product_Code") as "Cost_Price_P25",
percentile_cont(0.75) within group(order by "Cost_Price") over (partition by "Store_Code","Product_Code") as "Cost_Price_P75",
percentile_cont(0.25) within group(order by "Start_Price") over (partition by "Store_Code","Product_Code") as "Start_Price_P25",
percentile_cont(0.75) within group(order by "Start_Price") over (partition by "Store_Code","Product_Code") as "Start_Price_P75",
percentile_cont(0.25) within group(order by "Nett_Price") over (partition by "Store_Code","Product_Code") as "Nett_Price_P25",
percentile_cont(0.75) within group(order by "Nett_Price") over (partition by "Store_Code","Product_Code") as "Nett_Price_P75",
percentile_cont(0.25) within group(order by "Order_Quantity") over (partition by "Store_Code","Product_Code") as "Order_Quantity_P25",
percentile_cont(0.75) within group(order by "Order_Quantity") over (partition by "Store_Code","Product_Code") as "Order_Quantity_P75"
from order_hist
)
,
summ as (select --distinct
a.*,
c.* exclude ("Store_Code","Product_Code"),
b.* exclude ("Store_Code","Product_Code"),
case when b."Cost_Price_Med"=b."Cost_Price_Mean" then b."Cost_Price_Mean"+3*b."Cost_Price_Stdev"
	 when b."Cost_Price_Med"!=b."Cost_Price_Mean" then c."Cost_Price_P75"+1.5*(c."Cost_Price_P75"-c."Cost_Price_P25") end as "Cost_Price_Upper_Band",
case when b."Cost_Price_Med"=b."Cost_Price_Mean" then greatest(b."Cost_Price_Mean"-3*b."Cost_Price_Stdev",0)
	 when b."Cost_Price_Med"!=b."Cost_Price_Mean" then greatest(c."Cost_Price_P25"-1.5*(c."Cost_Price_P75"-c."Cost_Price_P25"),0) end as "Cost_Price_Lower_Band",
case when b."Start_Price_Med"=b."Start_Price_Mean" then b."Start_Price_Mean"+3*b."Start_Price_Stdev"
	 when b."Start_Price_Med"!=b."Start_Price_Mean" then c."Start_Price_P75"+1.5*(c."Start_Price_P75"-c."Start_Price_P25") end as "Start_Price_Upper_Band",
case when b."Start_Price_Med"=b."Start_Price_Mean" then greatest(b."Start_Price_Mean"-3*b."Start_Price_Stdev",0)
	 when b."Start_Price_Med"!=b."Start_Price_Mean" then greatest(c."Start_Price_P25"-1.5*(c."Start_Price_P75"-c."Start_Price_P25"),0) end as "Start_Price_Lower_Band",
case when b."Nett_Price_Med"=b."Nett_Price_Mean" then b."Nett_Price_Mean"+3*b."Nett_Price_Stdev"
	 when b."Nett_Price_Med"!=b."Nett_Price_Mean" then c."Nett_Price_P75"+1.5*(c."Nett_Price_P75"-c."Nett_Price_P25") end as "Nett_Price_Upper_Band",
case when b."Nett_Price_Med"=b."Nett_Price_Mean" then greatest(b."Nett_Price_Mean"-3*b."Nett_Price_Stdev",0)
	 when b."Nett_Price_Med"!=b."Nett_Price_Mean" then greatest(c."Nett_Price_P25"-1.5*(c."Nett_Price_P75"-c."Nett_Price_P25"),0) end as "Nett_Price_Lower_Band",
case when b."Order_Quantity_Med"=b."Order_Quantity_Mean" then round(b."Order_Quantity_Mean"+3*b."Order_Quantity_Stdev")
	 when b."Order_Quantity_Med"!=b."Order_Quantity_Mean" then round(c."Order_Quantity_P75"+1.5*(c."Order_Quantity_P75"-c."Order_Quantity_P25")) end as "Order_Quantity_Upper_Band",
case when b."Order_Quantity_Med"=b."Order_Quantity_Mean" then round(greatest(b."Order_Quantity_Mean"-3*b."Order_Quantity_Stdev",1))
	 when b."Order_Quantity_Med"!=b."Order_Quantity_Mean" then round(greatest(c."Order_Quantity_P25"-1.5*(c."Order_Quantity_P75"-c."Order_Quantity_P25"),1)) end as "Order_Quantity_Lower_Band"
from order_hist a
left join min_max_med b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
left join percentile c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
)

select --distinct 
*,
case when "Cost_Price">"Cost_Price_Upper_Band" or "Cost_Price"<"Cost_Price_Lower_Band" then True
	 when "Cost_Price"<="Cost_Price_Upper_Band" and "Cost_Price">="Cost_Price_Lower_Band" then False end as "Cost_Price_Outlier_Flag",
case when "Cost_Price">"Cost_Price_Upper_Band" then "Cost_Price_Upper_Band"
	 when "Cost_Price"<"Cost_Price_Lower_Band" then "Cost_Price_Lower_Band"
	 when "Cost_Price"<="Cost_Price_Upper_Band" and "Cost_Price">="Cost_Price_Lower_Band" then "Cost_Price" end as "Cost_Price_Correction",
case when "Start_Price">"Start_Price_Upper_Band" or "Start_Price"<"Start_Price_Lower_Band" then True
	 when "Start_Price"<="Start_Price_Upper_Band" and "Start_Price">="Start_Price_Lower_Band" then False end as "Start_Price_Outlier_Flag",
case when "Start_Price">"Start_Price_Upper_Band" then "Start_Price_Upper_Band"
	 when "Start_Price"<"Start_Price_Lower_Band" then "Start_Price_Lower_Band"
	 when "Start_Price"<="Start_Price_Upper_Band" and "Start_Price">="Start_Price_Lower_Band" then "Start_Price" end as "Start_Price_Correction",
case when "Nett_Price">"Nett_Price_Upper_Band" or "Nett_Price"<"Nett_Price_Lower_Band" then True
	 when "Nett_Price"<="Nett_Price_Upper_Band" and "Nett_Price">="Nett_Price_Lower_Band" then False end as "Nett_Price_Outlier_Flag",
case when "Nett_Price">"Nett_Price_Upper_Band" then "Nett_Price_Upper_Band"
	 when "Nett_Price"<"Nett_Price_Lower_Band" then "Nett_Price_Lower_Band"
	 when "Nett_Price"<="Nett_Price_Upper_Band" and "Nett_Price">="Nett_Price_Lower_Band" then "Nett_Price" end as "Nett_Price_Correction",
case when "Order_Quantity">"Order_Quantity_Upper_Band" or "Order_Quantity"<"Order_Quantity_Lower_Band" then True
	 when "Order_Quantity"<="Order_Quantity_Upper_Band" and "Order_Quantity">="Order_Quantity_Lower_Band" then False end as "Order_Quantity_Outlier_Flag",
case when "Order_Quantity">"Order_Quantity_Upper_Band" then "Order_Quantity_Upper_Band"
	 when "Order_Quantity"<"Order_Quantity_Lower_Band" then "Order_Quantity_Lower_Band"
	 when "Order_Quantity"<="Order_Quantity_Upper_Band" and "Order_Quantity">="Order_Quantity_Lower_Band" then "Order_Quantity" end as "Order_Quantity_Correction",
current_date() as "Insertion_Date"
from summ 
)
;