create or replace table BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_TRAIN_FEAT_LOG AS 
--create or replace view BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_TRAIN_FEAT_LOG_VW AS  
(select distinct 
a."Store_Code",
a."Product_Code",
a."Month_Start_Date",
a."MonthofYear",
sin(2 * pi() * a."MonthofYear"/12) as "MonthofYear_Sin",
cos(2 * pi() * a."MonthofYear"/12) as "MonthofYear_Cos",
a."Store_State_Code",
--a."Price_Group",
a."Retail_Pricing_Zone",
a."Material_Group_1_Code",
--a.Level2_Group,
--a.Level3_Group,
--a.Level4_Group,
a.Level5_Group,
--a."Manufacturer_Name",
--a."Brand",
a."Manufacturer_Brand",
a."Active_Ingredient",
a."PBS_Item_Code",
a."Is_PBS_Innovator_Flag",
a."Is_CSO_Eligible_Flag",
--a."Is_Marked_for_Deletion_Flag",
--a."Is_Core_Range_Flag",
--a."KVI_Flag",
a."Is_Private_Label_Flag",
a."Is_NDSS_Flag",
--a."Is_S100_Flag",
a."Drug_Type_Code",
--a."Drug_Type_Description",
--a."Days_In_Month",
a."Month_Holiday_Cnt",
a."Month_Holiday_DaysInBetween",
a."Next_Month_Holiday_Cnt",
a."Previous_Month_Holiday_Cnt",
a."Days_to_Next_Month_First_Holiday",
a."Days_from_Previous_Month_Last_Holiday",
a."MCS_Days_In_Month",
a."OOS_Days_In_Month",
a."MCS_Days_Percent_In_Month",
a."OOS_Days_Percent_In_Month",
a."Wholesale_Promo_Cnt", 
a."Monthly_Wholesale_Promo_Days_Max",
a."Promo_Minimum_Buy_Qty_Per_Order",
a."Wholesale_Promo_Discount_Percentage_Avg", 
a."Wholesale_Promo_Remaining_Days_Portion", 
--a."Next_Month_Wholesale_Promotion_Days",
a."Previous_Month_Wholesale_Promotion_Days",
a."Monthly_Retail_Promo_Days_Max",
a."Retail_Promo_Discount_Percentage_Avg",
a."Retail_Promo_Remaining_Days_Portion",
--a."Next_Month_Retail_Promotion_Days",
a."Previous_Month_Retail_Promotion_Days",
a."Monthly_Avg_Cost_Price_I",
a."Monthly_Avg_Start_Price",
a."Monthly_Avg_Nett_Price_I",
a."Monthly_Sigma_Avg_Nett_Price_I",
a."Monthly_Comp_Nett_Price_Index_I",
--a."Monthly_Avg_Discount_I",
--a."P12M_Max_Avg_Discount_I",
--a."P12M_Min_Avg_Discount_I",
--a."Monthly_Diff_Max_Avg_Discount_I",
--a."Monthly_Index_Max_Avg_Discount_I",
--a."Monthly_Diff_Min_Avg_Discount_I",
--a."Monthly_Index_Min_Avg_Discount_I",
a."Monthly_Avg_Margin_I",
--a."P12M_Max_Avg_Margin_I",
--a."P12M_Min_Avg_Margin_I",
--a."Monthly_Diff_Max_Avg_Margin_I",
a."Monthly_Index_Max_Avg_Margin_I",
--a."Monthly_Diff_Min_Avg_Margin_I",
a."Monthly_Index_Min_Avg_Margin_I",
--a."Monthly_Sigma_Avg_Nett_Price_I",
--a."Monthly_Sigma_Avg_Margin_I",
--a."P12M_Max_Sigma_Avg_Margin_I",
--a."P12M_Min_Sigma_Avg_Margin_I",
--a."Monthly_Diff_Max_Sigma_Avg_Margin_I",
--a."Monthly_Index_Max_Sigma_Avg_Margin_I",
--a."Monthly_Diff_Min_Sigma_Avg_Margin_I",
--a."Monthly_Index_Min_Sigma_Avg_Margin_I",
b.* exclude ("Store_Code","Product_Code","Month_Start_Date"),
a."Monthly_Store_Product_Order_Quantity",
a."Monthly_Store_Product_Order_Quantity_Log",
a."Monthly_Store_Product_Order_Label"
,current_date() as "Insertion_Date"
from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE_FEAT a
left join BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_TS_FEAT_LOG b
on a."Store_Code"=b."Store_Code"
and a."Product_Code"=b."Product_Code"
and a."Month_Start_Date"=b."Month_Start_Date"
and a."Month_Start_Date">=date('2022-09-01')
--inner join (select distinct 
--a."Store_Code",
----c."Demand_Group_Code"
--from BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_BASE a
--join edp_prod.pres."Dim_Customer_Retail_Store" b
--on a."Store_Code"=b."Store_Code"
--join edp_prod.pres."Dim_Customer" c
--on b."Site_Link_Code"=c."Site_Link_Code"
--c."Distribution_Channel_Name"='WHOLESALE'
--and c."Demand_Group_Code" is not null
--and upper(c."Demand_Group_Code") not in ('UKN','UNKNOWN','N/A','NA','BLANK')
--and c."Demand_Group_Code" in ('AMC','DDS','GUA')
--) d
--on a."Store_Code"=d."Store_Code"
--WHERE a."Month_Start_Date">=date('2022-09-01')
--a."Month_Start_Date">=date('2020-10-01')
--order by a."Store_Code",a."Product_Code",a."Month_Start_Date"
)
;