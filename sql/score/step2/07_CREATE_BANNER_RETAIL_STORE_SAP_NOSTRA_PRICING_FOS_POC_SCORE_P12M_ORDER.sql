create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_P12M_ORDER as 
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_P12M_ORDER_VW as
(
with sales_invoice as (
select 
distinct 
--"Customer_Retail_Store_Key",
"Store_Code",
"Product_Code",
--"Order_Date",
"Order_Month_Start_Date" as "Month_Start_Date",
--"Plant_Key",
round(sum("Cost_Price"*"Order_Quantity")/sum("Order_Quantity"),2) as "Monthly_Sigma_Avg_Cost_Price_Invoice",
--"Start_Price",
round(sum("Nett_Price"*"Order_Quantity")/sum("Order_Quantity"),2) as "Monthly_Sigma_Avg_Nett_Price_Invoice",
sum("Order_Quantity_Base_Unit") as "Monthly_Store_Product_Sigma_Order_Quantity_Invoice",
round(sum("Nett_Price"*"Order_Quantity"),2) as "Monthly_Sigma_Sales_Order_Revenue",
round(sum("COGS_Amount"),2) as "Monthly_Sigma_COGS",
"Monthly_Sigma_Sales_Order_Revenue"-"Monthly_Sigma_COGS" as "Monthly_Sigma_GP" 
--,"Promotion_Brief_Detail_Key",
--'SIGMA' AS "Supplier_Master_Type_Name"
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
a."Cost_Price",
a."Start_Price",
a."Nett_Price",
round(a."Invoice_Quantity",0) "Order_Quantity",
round(a."Invoice_Quantity_Base_Unit",0) "Order_Quantity_Base_Unit",
a."COGS_Amount",
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
and "Order_Quantity_Base_Unit">=1
and --"Order_Date" >=date('2019-10-01')
"Order_Date" >=date('2021-08-27')
--and "Order_Date" <=date('2023-08-31')
and "Order_Date" <=Current_Date()
)
group by all
)
--,
--p12m_order as 
--(
select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date" as "Current_Month_Start_Date",
c."Month_Start_Date" as "Past_Month_Start_Date",
c."OOS_Days_In_Month" as "OOS_Days",
c."Wholesale_Promo_Flag",
case when b."Monthly_Sigma_Avg_Cost_Price_Invoice" is not null then b."Monthly_Sigma_Avg_Cost_Price_Invoice"
     else c."Monthly_Avg_Cost_Price_I" end as "Monthly_Avg_Cost_Price",
case when b."Monthly_Sigma_Avg_Nett_Price_Invoice" is not null then b."Monthly_Sigma_Avg_Nett_Price_Invoice"
     else c."Monthly_Sigma_Avg_Nett_Price_I" end as "Monthly_Sigma_Avg_Nett_Price",
c."Monthly_NonSigma_Avg_Nett_Price_I" as "Monthly_NonSigma_Avg_Nett_Price",
nvl(b."Monthly_Store_Product_Sigma_Order_Quantity_Invoice",0) "Monthly_Store_Product_Sigma_Order_Quantity",
nvl(c."Monthly_Store_Product_NonSigma_Order_Quantity",0) "Monthly_Store_Product_NonSigma_Order_Quantity",
nvl(b."Monthly_Sigma_COGS",0) "Monthly_Sigma_COGS",
nvl(b."Monthly_Sigma_Sales_Order_Revenue",0) "Monthly_Sigma_Sales_Order_Revenue",
nvl(b."Monthly_Sigma_GP",0) "Monthly_Sigma_GP",
nvl(b."Monthly_Store_Product_Sigma_Order_Quantity_Invoice",0) + nvl(c."Monthly_Store_Product_NonSigma_Order_Quantity",0) "Monthly_Store_Product_Total_Order_Quantity",
case when "Monthly_Store_Product_Total_Order_Quantity">0 then round(100*nvl(b."Monthly_Store_Product_Sigma_Order_Quantity_Invoice",0)/"Monthly_Store_Product_Total_Order_Quantity",2)
      else 0 end as "Monthly_Compliance"
,current_date() as "Insertion_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE a
left join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT c
on a."Store_Code"=c."Store_Code"
and a."Product_Code"=c."Product_Code"
and c."Month_Start_Date"<a."Month_Start_Date"
and c."Month_Start_Date">=dateadd('month',-12,a."Month_Start_Date")
left join sales_invoice b
on c."Store_Code"=b."Store_Code"
and c."Product_Code"=b."Product_Code"
and c."Month_Start_Date"=b."Month_Start_Date"
--)
)
;