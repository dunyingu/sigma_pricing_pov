create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_BASE AS  
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_BASE_VW AS
(select distinct
a.* exclude "Insertion_Date",
b.* exclude (
"Month_Start_Date",
"Store_Code",
"Product_Code",
"Next_Month_Holiday_Cnt",
"Next_Month_First_Holiday_Date",
"Days_to_Next_Month_First_Holiday",
"MCS_Days_In_Month",
"OOS_Days_In_Month",
"MCS_Days_Percent_In_Month",
"OOS_Days_Percent_In_Month",
"Next_Month_Wholesale_Promotion_Days",
"Next_Month_Retail_Promotion_Days",
"Monthly_Avg_Cost_Price_I",
"Monthly_Avg_Start_Price_I",
"Monthly_Avg_Nett_Price_I",
"Monthly_Sigma_Avg_Nett_Price_I",
"Monthly_NonSigma_Avg_Nett_Price_I",
"Monthly_Avg_Discount_I",
"Monthly_Avg_Margin_I",
"Monthly_Sigma_Avg_Margin_I",
"Monthly_Comp_Nett_Price_Index_I",
"P12M_Min_Avg_Discount_I",
"P12M_Max_Avg_Discount_I",
"P12M_Min_Avg_Margin_I",
"P12M_Max_Avg_Margin_I",
"P12M_Min_Sigma_Avg_Margin_I",
"P12M_Max_Sigma_Avg_Margin_I",
"Monthly_Diff_Max_Avg_Discount_I",
"Monthly_Index_Max_Avg_Discount_I",
"Monthly_Diff_Min_Avg_Discount_I",
"Monthly_Index_Min_Avg_Discount_I",
"Monthly_Diff_Max_Avg_Margin_I",
"Monthly_Index_Max_Avg_Margin_I",
"Monthly_Diff_Min_Avg_Margin_I",
"Monthly_Index_Min_Avg_Margin_I",
"Monthly_Diff_Max_Sigma_Avg_Margin_I",
"Monthly_Index_Max_Sigma_Avg_Margin_I",
"Monthly_Diff_Min_Sigma_Avg_Margin_I",
"Monthly_Index_Min_Sigma_Avg_Margin_I",
"Insertion_Date"
)
,current_date() as "Insertion_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT a
inner join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_SCORE_KIA_FEAT b
on a."Month_Start_Date"=b."Month_Start_Date"
and a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
)
;