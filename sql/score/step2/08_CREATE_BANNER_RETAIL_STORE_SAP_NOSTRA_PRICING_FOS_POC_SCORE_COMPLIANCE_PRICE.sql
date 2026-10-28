create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE AS  
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE_VW AS
(
with compliance as (
select distinct 
"Store_Code",
"Product_Code",
"Current_Month_Start_Date" as "Month_Start_Date",
case when ("P12M_Store_Product_Sigma_Order_Quantity"+"P12M_Store_Product_NonSigma_Order_Quantity")>0 then round(100*"P12M_Store_Product_Sigma_Order_Quantity"/("P12M_Store_Product_Sigma_Order_Quantity"+"P12M_Store_Product_NonSigma_Order_Quantity"),2)
      else 0 end as "P12M_Compliance"
from 
(
select 
"Store_Code",
"Product_Code",
"Current_Month_Start_Date",
sum("Monthly_Store_Product_Sigma_Order_Quantity") as "P12M_Store_Product_Sigma_Order_Quantity",
sum("Monthly_Store_Product_NonSigma_Order_Quantity") as "P12M_Store_Product_NonSigma_Order_Quantity"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_P12M_ORDER 
group by all 
)
)
,
price_qty_array as 
(
select --"Series_ID",
"Store_Code","Product_Code",
"Month_Start_Date",
array_agg("Price_Quantity") as "Price_Quantity_Array"
from 
(
select distinct 
--"Series_ID",
"Store_Code","Product_Code",
"Month_Start_Date",
Concat("Monthly_Avg_Nett_Price_Perm"::string,'_',"Monthly_Store_Product_Order_Quantity_Pred"::string) "Price_Quantity"
from 
BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE
)
group by all
)
,
price_sensitivity_measure as (
select --"Series_ID",
"Store_Code","Product_Code",
"Month_Start_Date",
"Price_Quantity_Array",
PRICE_SENSITIVITY("Price_Quantity_Array") "Price_Qty_Percent_Change"
from price_qty_array 
)
,
compliance_percent_rank as (
select
--"Series_ID",
"Store_Code",
"Product_Code",
"Month_Start_Date",
"P12M_Compliance",
--ifnull("P12M_Compliance",0) "P12M_Compliance",
PERCENT_RANK() OVER (PARTITION BY "Product_Code","Month_Start_Date" ORDER BY ifnull("P12M_Compliance",0)) AS "P12_Store_Product_Compliance_Percent_Rank"
from compliance
--Order by "Month_Start_Date","Product_Code","P12_Store_Product_Compliance_Percent_Rank"
)
,
compliance_percent_rank_med as (
select "Product_Code",
"Month_Start_Date",
median("P12M_Compliance") as "P12_Store_Product_Compliance_Med",
median("P12_Store_Product_Compliance_Percent_Rank") as "P12_Store_Product_Compliance_Percent_Rank_Med"
from 
(
select distinct "Product_Code",
"Month_Start_Date",
"P12M_Compliance",
"P12_Store_Product_Compliance_Percent_Rank"
from compliance_percent_rank
order by "Month_Start_Date","Product_Code","P12M_Compliance"
)
group by all
)
,
price_sensitivity_percent_rank as (
select 
--"Series_ID",
"Store_Code",
"Product_Code",
"Month_Start_Date",
"Price_Qty_Percent_Change",
PERCENT_RANK() OVER (PARTITION BY "Product_Code","Month_Start_Date" ORDER BY "Price_Qty_Percent_Change" asc) AS "Price_Qty_Percent_Change_Percent_Rank"
from price_sensitivity_measure
)
,
price_sensitivity_percent_rank_med as (
select "Product_Code",
"Month_Start_Date",
median("Price_Qty_Percent_Change") as "Price_Qty_Percent_Change_Med",
median("Price_Qty_Percent_Change_Percent_Rank") as "Price_Qty_Percent_Change_Percent_Rank_Med"
from 
(
select distinct "Product_Code",
"Month_Start_Date",
"Price_Qty_Percent_Change",
"Price_Qty_Percent_Change_Percent_Rank"
from price_sensitivity_percent_rank
order by "Month_Start_Date","Product_Code","Price_Qty_Percent_Change"
)
group by all
)

select distinct 
a.*, 
b."P12_Store_Product_Compliance_Med",
b."P12_Store_Product_Compliance_Percent_Rank_Med",
c.* exclude("Store_Code","Product_Code","Month_Start_Date")
,current_date() as "Insertion_Date"
from compliance_percent_rank a
left join compliance_percent_rank_med b
on a."Product_Code"=b."Product_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
left join (
select distinct 
a.*, 
b.*exclude("Product_Code","Month_Start_Date")
from price_sensitivity_percent_rank a
left join price_sensitivity_percent_rank_med b
on a."Product_Code"=b."Product_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
) c
on a."Product_Code"=c."Product_Code"
and a."Store_Code"=c."Store_Code"
and a."Month_Start_Date"=c."Month_Start_Date"
order by a."Month_Start_Date",a."Product_Code",a."P12_Store_Product_Compliance_Percent_Rank"
)
;