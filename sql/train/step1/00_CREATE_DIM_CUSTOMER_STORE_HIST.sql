CREATE OR REPLACE TABLE CORE.DIM_CUSTOMER_STORE_HIST AS 
--CREATE OR REPLACE VIEW CORE.DIM_CUSTOMER_STORE_HIST_VW  AS 
(
select distinct
"Customer_Key",
"Site_Link_Code",
"Customer_Retail_Store_Key",
"Store_Code",
"Customer_Attribute_Key",
"Demand_Group_Code",
"Banner_Group_Code",
"Customer_Band_Code",
"Owner_Code",
"Group_Code",
"Mylan_Group_Code",
"Arrow_Group_Code",
"Apotex_Group_Code",
"Customer_Type_Code",
"Price_List_Type_Code",
"Order_Date" "Effective_Start_Date",
nvl(lead("Order_Date") over (partition by "Store_Code" order by "Order_Date"),date('2099-12-31')) "Effective_End_Date",
CURRENT_DATE() "Insertion_Date"
from 
(
select distinct 
DATE(a."Order_Date_Key",'yyyymmdd') "Order_Date",
date_trunc('week',"Order_Date") "Order_Week_Start_Date",
date_trunc('month',"Order_Date") "Order_Month_Start_Date",
a."Sold_To_Customer_Key" "Customer_Key",
a."Sold_To_Customer_Attribute_Key" "Customer_Attribute_Key",
e."Site_Link_Code",
e."Customer_Retail_Store_Key",
e."Store_Code",
b."Demand_Group_Code",
b."Banner_Group_Code",
b."Customer_Band_Code",
b."Owner_Code",
b."Group_Code",
b."Mylan_Group_Code",
b."Arrow_Group_Code",
b."Apotex_Group_Code",
b."Customer_Type_Code",
b."Price_List_Type_Code",
b."ETL_ROW_EFFECTIVE_DATE" "Customer_Attribute_Effective_Start_Date",
b."ETL_ROW_EXPIRY_DATE" "Customer_Attribute_Effective_End_Date"
from "EDP_PROD"."PRES"."Fact_Sales_Order" a
left join "EDP_PROD"."PRES"."Dim_Customer_Attribute" b
on a."Sold_To_Customer_Attribute_Key"=b."Customer_Attribute_Key"
left JOIN edp_prod.pres."Dim_Customer" f
ON a."Sold_To_Customer_Key"=f."Customer_Key"
and f."Customer_Key">0 
and f."Distribution_Channel_Name"='WHOLESALE'
left join edp_prod.pres."Dim_Customer_Retail_Store" e
on f."Site_Link_Code" = e."Site_Link_Code"
where "Order_Date">=date('2021-08-27') and "Order_Date" <=Current_Date()
and a."Sold_To_Customer_Key">0
and e."Customer_Retail_Store_Key" is not null --and e."Customer_Retail_Store_Key"!='N/A'
and e."Store_Code" IS NOT NULL AND e."Site_Link_Code" IS NOT NULL 
AND e."Store_Code"!='N/A' AND e."Site_Link_Code"!='N/A'
AND e."Store_Code"!='NA' AND e."Site_Link_Code"!='NA'
AND e."Store_Code"!='UKN' AND e."Site_Link_Code"!='UKN'
--and not "Order_Date" between "Customer_Attribute_Effective_Start_Date" and "Customer_Attribute_Effective_End_Date"
)
)
;