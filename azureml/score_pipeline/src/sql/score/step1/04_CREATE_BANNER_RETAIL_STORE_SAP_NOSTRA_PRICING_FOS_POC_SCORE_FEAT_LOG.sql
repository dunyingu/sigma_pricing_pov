create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG AS  
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_FEAT_LOG_VW AS  
(select --concat("Store_Code",'_',"Product_Code") as "Series_ID",
* exclude (
--"Store_Code",
--"Product_Code",
--"Month_Start_Date",
"MonthofYear_Sin",
"MonthofYear_Cos",
"Material_Group_1_Code",
"PBS_Item_Code",
"Is_PBS_Innovator_Flag",
"Is_CSO_Eligible_Flag",
"Is_NDSS_Flag",
"Drug_Type_Code",
"MCS_Days_In_Month",
"OOS_Days_In_Month",
"Monthly_Avg_Cost_Price_I",
"Monthly_Avg_Start_Price",
"Monthly_Avg_Nett_Price_I",
"Monthly_Sigma_Avg_Nett_Price_I",
"Monthly_Comp_Nett_Price_Index_I"
,"Insertion_Date"
)
,current_date() as "Insertion_Date"
FROM BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_FEAT_LOG
WHERE "Material_Group_1_Code" in ('FOS','OTC')
and concat("Store_Code",'_',"Product_Code") in (select distinct concat("Store_Code",'_',"Product_Code") 
from BANNER_RETAIL_STORE_WHOLESALE_ORDER_HIST_SAP_NOSTRA_POC)
order by --"Series_ID"
"Store_Code","Product_Code"
,"Month_Start_Date"
)
;