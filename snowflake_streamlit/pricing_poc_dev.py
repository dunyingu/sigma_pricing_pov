# Import python packages
import streamlit as st
#import streamlit.components.v1 as components
#import altair as alt
#import mpld3
#from mpld3 import plugins
from PIL import Image

#import snowflake.snowpark
#from snowflake.snowpark.session import Session
from snowflake.snowpark.context import get_active_session

import pandas as pd
import numpy as np
import re

import matplotlib.pyplot as plt
from matplotlib import pyplot as plt
#from matplotlib import colors as plt_colors
import seaborn as sns


# Write directly to the app
st.set_page_config(
    #page_title="Pricing POC App",
    #page_icon="🏢",
    layout='centered'#"centered" #'wide'
    ,initial_sidebar_state="expanded"#"collapsed"
)

logo=Image.open("Sigma-Healthcare-FullLogo.png")
logo_resized=logo.resize((150,61))
st.image(logo_resized)

st.header("Pricing POC App")

st.write(
    """The POC selects top volume FOS products for each banner store 
    and builds a pricing model to predict the price change impact on the monthly demand.  
    This app visualizes the model prediction on pricing impact and provides some insights.
    """
)


@st.cache_data
def get_stores(_session):
	query = f"""
	select distinct --"Store_Code"
	--,
	"Store_Name"
	from --WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE
	WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM
	order by "Store_Name"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_products(_session):
	query = f"""
	select distinct --"Product_Code"
	--,
	"Product_Name"
	from --WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE
	WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM
	order by "Product_Name"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_months(_session):
	query = f"""
	select distinct "Month_Start_Date"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE
    --WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE
    order by "Month_Start_Date"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_stores_for_product(_session,product_name):
	query = f"""
	select distinct --"Store_Code"
	--,
	"Store_Name"
	from --WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE
	WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM
	where "Product_Name"='{product_name}'
	order by "Store_Name"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_products_for_store(_session,store_name):
	query = f"""
	select distinct --"Product_Code"
	--,
	"Product_Name"
	from --WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE
	WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM
	where "Store_Name"='{store_name}'
	order by "Product_Name"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_months_for_product_store(_session,product_name,store_name):
	query = f"""
	select distinct "Month_Start_Date"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
    --WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE
    join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
    on a."Product_Code"=b."Product_Code"
    and a."Store_Code"=b."Store_Code"
    and b."Product_Name"='{product_name}'
    and b."Store_Name"='{store_name}'
    order by "Month_Start_Date"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_past_summary(_session,product_name,store_name,month_start_date):
	
	query = f"""
		select distinct 
	*
	from
	(select distinct 
	a."Month_Start_Date" as "Current_Month_Start_Date",
	a."Store_Code",
	a."Product_Code",
	b."Past_Month_Start_Date" as "Month_Start_Date",
	'SIGMA' as "Supplier",
	b."Monthly_Sigma_Avg_Nett_Price" as "Monthly_Avg_Nett_Price_I",
	--b."Monthly_NonSigma_Avg_Nett_Price",
	b."Monthly_Store_Product_Sigma_Order_Quantity" as "Monthly_Total_Order_Quantity"
	--b."Monthly_Store_Product_NonSigma_Order_Quantity"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
	left join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_P12M_ORDER b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Past_Month_Start_Date"<a."Month_Start_Date"
	and b."Past_Month_Start_Date">=dateadd('month',-12,a."Month_Start_Date")
	join EDP_ANALYTICS_SANDPIT.WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM c
	on a."Product_Code"=c."Product_Code"
	and a."Store_Code"=c."Store_Code"
	and c."Product_Name"='{product_name}'
	and c."Store_Name"='{store_name}'
	WHERE a."Month_Start_Date"=date('{month_start_date}') 
	--and CONCAT(a."Store_Code",'_',a."Product_Code") in (select distinct CONCAT("Store_Code",'_',"Product_Code")
	--from EDP_ANALYTICS_SANDPIT.WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM)
	--and a."Month_Start_Date">=date('2022-09-01')
	)
	union
	(select distinct 
	a."Month_Start_Date" as "Current_Month_Start_Date",
	a."Store_Code",
	a."Product_Code",
	b."Past_Month_Start_Date" as "Month_Start_Date",
	'NonSIGMA' as "Supplier",
	--b."Monthly_Sigma_Avg_Nett_Price",
	b."Monthly_NonSigma_Avg_Nett_Price" as "Monthly_Avg_Nett_Price_I",
	--b."Monthly_Store_Product_Sigma_Order_Quantity",
	b."Monthly_Store_Product_NonSigma_Order_Quantity" as "Monthly_Total_Order_Quantity"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
	left join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_P12M_ORDER b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Past_Month_Start_Date"<a."Month_Start_Date"
	and b."Past_Month_Start_Date">=dateadd('month',-12,a."Month_Start_Date")
	join EDP_ANALYTICS_SANDPIT.WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM c
	on a."Product_Code"=c."Product_Code"
	and a."Store_Code"=c."Store_Code"
	and c."Product_Name"='{product_name}'
	and c."Store_Name"='{store_name}'
	WHERE a."Month_Start_Date"=date('{month_start_date}') 
	--and CONCAT(a."Store_Code",'_',a."Product_Code") in (select distinct CONCAT("Store_Code",'_',"Product_Code")
	--from EDP_ANALYTICS_SANDPIT.WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM)
	--and a."Month_Start_Date">=date('2022-09-01')
	)
	order by "Supplier","Month_Start_Date"
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_perm_price(_session,product_name,store_name,month_start_date,price_change_slide):
	price_change_level = round(1+(price_change_slide)/100,2)

	query = f"""
	select distinct a."Monthly_Avg_Nett_Price_Perm" as "Nett_Price_Perm"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	and b."Store_Name"='{store_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	and a."Price_Change_Level"={price_change_level}
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_perm_quantity(_session,product_name,store_name,month_start_date,price_change_slide):
	price_change_level = round(1+(price_change_slide)/100,2)

	query = f"""
	select distinct a."Monthly_Store_Product_Order_Quantity_Pred"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	and b."Store_Name"='{store_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	and a."Price_Change_Level"={price_change_level}
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_perm_revenue(_session,product_name,store_name,month_start_date,price_change_slide):
	price_change_level = round(1+(price_change_slide)/100,2)

	query = f"""
	select distinct a."Monthly_Store_Product_Order_Revenue_Pred" as "Monthly_Store_Product_Order_Revenue" 
	--a."Monthly_Store_Product_Order_GP_Pred" as "Monthly_Store_Product_Order_GP" 
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	and b."Store_Name"='{store_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	and a."Price_Change_Level"={price_change_level}
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_perm_score(_session,product_name,store_name,month_start_date):
	#price_change_level = round(1+(price_change_slide)/100,2)

	query = f"""
	select distinct 
	a."Price_Change_Level",
	a."Monthly_Avg_Nett_Price_Perm" as "Nett_Price_Perm",
	a."Recomm_Nett_Price_Revenue" as "Recomm_Nett_Price",
	--a."Recomm_Nett_Price_GP" as "Recomm_Nett_Price",
	a."Monthly_Store_Product_Order_Quantity_Pred",
	a."Monthly_Store_Product_Order_Cost_Pred" as "Monthly_Store_Product_Order_Cost",
	a."Monthly_Store_Product_Order_Revenue_Pred" as "Monthly_Store_Product_Order_Revenue",
	a."Monthly_Store_Product_Order_GP_Pred" as "Monthly_Store_Product_Order_GP"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_PRICE_PERM_SCORE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	and b."Store_Name"='{store_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	"""
    
	return _session.sql(query).to_pandas()

@st.cache_data
def get_product_compliance_price_sensitivity(_session,product_name,month_start_date):

	query = f"""
	select distinct 
    a."Store_Code",
    b."Store_Name",
	a."P12M_Compliance" as "P12_Store_Product_Compliance",
	a."P12_Store_Product_Compliance_Percent_Rank",
	a."P12_Store_Product_Compliance_Med",
	a."P12_Store_Product_Compliance_Percent_Rank_Med",
	a."Price_Qty_Percent_Change",
	a."Price_Qty_Percent_Change_Percent_Rank",
	a."Price_Qty_Percent_Change_Med",
	a."Price_Qty_Percent_Change_Percent_Rank_Med"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	"""
    
	return _session.sql(query).to_pandas()


@st.cache_data
def get_store_compliance_price_sensitivity(_session,product_name,store_name,month_start_date):

	query = f"""
	select distinct 
	a."P12M_Compliance" as "P12_Store_Product_Compliance",
	a."P12_Store_Product_Compliance_Percent_Rank",
	a."P12_Store_Product_Compliance_Med",
	a."P12_Store_Product_Compliance_Percent_Rank_Med",
	a."Price_Qty_Percent_Change",
	a."Price_Qty_Percent_Change_Percent_Rank",
	a."Price_Qty_Percent_Change_Med",
	a."Price_Qty_Percent_Change_Percent_Rank_Med"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_SCORE_COMPLIANCE_PRICE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	on a."Product_Code"=b."Product_Code"
	and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	and b."Store_Name"='{store_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	"""
    
	return _session.sql(query).to_pandas()


@st.cache_data
def get_category_compliance_price_sensitivity(_session,product_name,month_start_date):

	query = f"""
	select distinct 
    a."Store_Code",
    a."Store_Name",
    a."Category",
    --concat(b."Level_3_Name",' ',b."Level_4_Name") as "Category",
	a."P12M_Category_Compliance",
	a."P12M_Store_Category_Compliance_Percent_Rank",
	a."P12M_Store_Category_Compliance_Med",
	a."P12M_Store_Category_Compliance_Percent_Rank_Med",
	a."Category_Price_Qty_Percent_Change",
	a."Category_Price_Qty_Percent_Change_Percent_Rank",
	a."Category_Price_Qty_Percent_Change_Med",
	a."Category_Price_Qty_Percent_Change_Percent_Rank_Med"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_CATEGORY_SCORE_COMPLIANCE_PRICE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	--on a."Category"=b."Level_4_Name"
	on a."Category"=concat(b."Level_3_Name",' ',b."Level_4_Name") 
	--and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	"""
    
	return _session.sql(query).to_pandas()


@st.cache_data
def get_store_category_compliance_price_sensitivity(_session,product_name,store_name,month_start_date):

	query = f"""
	select distinct 
    a."Store_Code",
    a."Store_Name",
    a."Category",
    --concat(b."Level_3_Name",' ',b."Level_4_Name") as "Category",
	a."P12M_Category_Compliance",
	a."P12M_Store_Category_Compliance_Percent_Rank",
	a."P12M_Store_Category_Compliance_Med",
	a."P12M_Store_Category_Compliance_Percent_Rank_Med",
	a."Category_Price_Qty_Percent_Change",
	a."Category_Price_Qty_Percent_Change_Percent_Rank",
	a."Category_Price_Qty_Percent_Change_Med",
	a."Category_Price_Qty_Percent_Change_Percent_Rank_Med"
	from WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_CATEGORY_SCORE_COMPLIANCE_PRICE a
	join WRK.BANNER_RETAIL_STORE_SAP_NOSTRA_PRICING_FOS_POC_DIM b
	--on a."Category"=b."Level_4_Name"
	on a."Category"=concat(b."Level_3_Name",' ',b."Level_4_Name") 
	--and a."Store_Code"=b."Store_Code"
	and b."Product_Name"='{product_name}'
	where a."Month_Start_Date"=date('{month_start_date}')
	and a."Store_Name"='{store_name}'
	"""
    
	return _session.sql(query).to_pandas()


st.sidebar.markdown(''' > **How to use this app**

1. Select a product then a store which has ordered the product (There are about 70k product-store pairs in the POC) and a month 
2. Tab1 to summarize past 12 months' (P12M) pricing and order history for the selected product-store pair before the selected month
3. Tab2 to analyze the price change impact on the quantity and revenue for the selected product-store pair in the selected month, with a recommended price to get highest revenue
4. Tab3 to compare the chosen store against other stores in terms of compliance and price sensitivity for a given product in the selected month
5. Tab4 to compare the chosen store against other stores in terms of compliance and price sensitivity for the category of the selected product in the selected month
''')

session=get_active_session()

stores=get_stores(session)
products=get_products(session)
months=get_months(session)

product_selection = st.sidebar.selectbox("Product",
                                 options=products
                                )
product_selection=product_selection.replace("'","\\'")

store_selection = st.sidebar.selectbox("Store",
                               options=get_stores_for_product(session,product_selection)['Store_Name']
                                )
store_selection=store_selection.replace("'","\\'")

#month_selection = st.sidebar.selectbox("Month Start Date",
#                                      options=months 
#                                      )

month_selection = st.sidebar.selectbox("Month Start Date",
                                       options=get_months_for_product_store(session,product_selection,store_selection)['Month_Start_Date']
                                      )

tab1, tab2, tab3, tab4 = st.tabs(["P12M Summary", "What-if Analysis", "Product Compliance & Price Sensitivity","Category Compliance & Price Sensitivity"])


with tab1:
    #st.subheader("P12M Order Price & Quantity Summary")
    
    df_past_summary=get_past_summary(session,product_selection,store_selection,month_selection)
    past_month=df_past_summary["Month_Start_Date"].astype(str).unique()
    past_sigma_price=df_past_summary.loc[df_past_summary["Supplier"]=='SIGMA',"Monthly_Avg_Nett_Price_I"]
    past_nonsigma_price=df_past_summary.loc[df_past_summary["Supplier"]=='NonSIGMA',"Monthly_Avg_Nett_Price_I"]
    past_sigma_quantity=df_past_summary.loc[df_past_summary["Supplier"]=='SIGMA',"Monthly_Total_Order_Quantity"]
    past_nonsigma_quantity=df_past_summary.loc[df_past_summary["Supplier"]=='NonSIGMA',"Monthly_Total_Order_Quantity"]
    
    X_axis = np.arange(len(past_month))
    
    if not (past_sigma_price.isnull().all() & past_nonsigma_price.isnull().all()):
        COLOR_PRICE = 'blue'
        COLOR_SIGMA = 'purple'
        COLOR_NONSIGMA = 'orange'
        w=0.4
        fig1, ax0 = plt.subplots(1,figsize=(28, 14),)

        if not past_sigma_price.isnull().all():
            ax0_lp1 = sns.lineplot(x=X_axis,y=past_sigma_price,ax=ax0, color=COLOR_SIGMA, marker='o',markersize=24, lw=6, label='Sigma Avg Nett Price')
        if not past_nonsigma_price.isnull().all():
            ax0_lp2 = sns.lineplot(x=X_axis,y=past_nonsigma_price,ax=ax0, color=COLOR_NONSIGMA, marker='o',markersize=24, lw=6, label='Competitors Avg Nett Price')
        
        ax1 = ax0.twinx()
        
        if sum(past_sigma_quantity)>0:
            ax1_bar1 =ax1.bar(X_axis,past_sigma_quantity, width=w, color=COLOR_SIGMA, alpha=0.5, label='Order to Sigma')
        if sum(past_nonsigma_quantity)>0:
            ax1_bar2 = ax1.bar(X_axis+w,past_nonsigma_quantity, width=w, color=COLOR_NONSIGMA,  alpha=0.5, label='Order to Competitors')
        
        ax0.set_xticks(X_axis,past_month)
        ax0.set_xticklabels(past_month,rotation=45,fontsize=32)
        ax0.set_xlabel("Month Start Date", fontsize=36)
        ax0.tick_params(axis="x", labelsize=32)
        
        ax0.set_ylabel("Nett Price ($)", color=COLOR_PRICE, fontsize=36)
        ax0.tick_params(axis="y", labelcolor=COLOR_PRICE, labelsize=32)
        
        if sum(past_sigma_quantity)>0:
            ax1.tick_params(axis="y", labelcolor=COLOR_SIGMA, labelsize=32)
            ax1.set_ylabel("Order Quantity (in Base Units)", color=COLOR_SIGMA, fontsize=36)
        else:
            ax1.tick_params(axis="y", labelcolor=COLOR_NONSIGMA, labelsize=32)
            ax1.set_ylabel("Order Quantity (in Base Units)", color=COLOR_NONSIGMA, fontsize=36)
        
        ax0.legend(ax0.get_legend_handles_labels()[0]+ax1.get_legend_handles_labels()[0],ax0.get_legend_handles_labels()[1]+ax1.get_legend_handles_labels()[1],loc="best",shadow=True,prop={'size': 24})
        st.pyplot(fig1)
    else:
        st.write("**No Order Records in Past 12 Months**")


with tab2:
    #st.subheader("Nett Price vs. Quantity & Revenue")
    
    df_price_perm_score_plot=get_perm_score(session,product_selection,store_selection,month_selection)
    starting_price=df_price_perm_score_plot[df_price_perm_score_plot["Price_Change_Level"]==1]["Nett_Price_Perm"].iloc[0]
    #st.text_area("Starting_Nett_Price",f'{starting_price}',max_chars=10)
    st.write("**Starting_Nett_Price**", starting_price)
    
    price_change_slide = st.slider(
                                   "**Price Change (%)**",
                                    min_value=-10,
                                    max_value=10,
                                    help='Use this slider to change Nett Price by up to +/- 10%',
                                    step=1,
                                    value=0
                                    )
    
    
    price = df_price_perm_score_plot["Nett_Price_Perm"]
    quantity = df_price_perm_score_plot["Monthly_Store_Product_Order_Quantity_Pred"]
    revenue = df_price_perm_score_plot["Monthly_Store_Product_Order_Revenue"]
    
    #price_change_level = round(1+(price_change_slide)/100,2)
    
    plot_price = get_perm_price(session,product_selection,store_selection,month_selection,price_change_slide)["Nett_Price_Perm"].iloc[0]
    plot_quantity = get_perm_quantity(session,product_selection,store_selection,month_selection,price_change_slide)["Monthly_Store_Product_Order_Quantity_Pred"].iloc[0]
    plot_revenue = get_perm_revenue(session,product_selection,store_selection,month_selection,price_change_slide)["Monthly_Store_Product_Order_Revenue"].iloc[0]
    #plot_price =df_price_perm_score_plot[df_price_perm_score_plot["Price_Change_Level"]==price_change_level]["Nett_Price_Perm"].iloc[0]
    #plot_quantity =df_price_perm_score_plot[df_price_perm_score_plot["Price_Change_Level"]==price_change_level]["Monthly_Store_Product_Order_Quantity_Pred"].iloc[0]
    #plot_revenue =df_price_perm_score_plot[df_price_perm_score_plot["Price_Change_Level"]==price_change_level]["Monthly_Store_Product_Order_Revenue"].iloc[0]
    
    recomm_price =df_price_perm_score_plot[df_price_perm_score_plot["Recomm_Nett_Price"]==1]["Nett_Price_Perm"].iloc[0]
    recomm_quantity =df_price_perm_score_plot[df_price_perm_score_plot["Recomm_Nett_Price"]==1]["Monthly_Store_Product_Order_Quantity_Pred"].iloc[0]
    recomm_revenue =df_price_perm_score_plot[df_price_perm_score_plot["Recomm_Nett_Price"]==1]["Monthly_Store_Product_Order_Revenue"].iloc[0]
    
    recomm_price =df_price_perm_score_plot[df_price_perm_score_plot["Recomm_Nett_Price"]==1]["Nett_Price_Perm"].iloc[0]
    recomm_quantity =df_price_perm_score_plot[df_price_perm_score_plot["Recomm_Nett_Price"]==1]["Monthly_Store_Product_Order_Quantity_Pred"].iloc[0]
    recomm_revenue =df_price_perm_score_plot[df_price_perm_score_plot["Recomm_Nett_Price"]==1]["Monthly_Store_Product_Order_Revenue"].iloc[0]
    
    COLOR_QUANTITY = "royalblue"
    COLOR_REVENUE = "green" #'purple'
    
    fig2, ax2 = plt.subplots(1,figsize=(28, 14))
    ax3 = ax2.twinx()
    
    sns.lineplot(x=price,y=quantity,ax=ax2, color=COLOR_QUANTITY, lw=6)
    sns.lineplot(x=price,y=revenue,ax=ax3, color=COLOR_REVENUE, lw=6)
    
    ax2.plot(plot_price,plot_quantity,'ko',markersize=24,label='selected_price')
    ax2.plot(recomm_price,recomm_quantity,'r*',markersize=24,alpha=0.5,label='recommended_price')
    
    ax2.set_xlabel("Nett Price ($)", fontsize=36)
    ax2.tick_params(axis="x", labelsize=32)
    ax2.set_ylabel("Order Quantity (Base Units)", color=COLOR_QUANTITY, fontsize=36)
    ax2.tick_params(axis="y", labelcolor=COLOR_QUANTITY, labelsize=32)
    
    ax3.plot(plot_price,plot_revenue,'ko',markersize=24) #,label='selected_price'
    ax3.plot(recomm_price,recomm_revenue,'r*',markersize=24,alpha=0.5) #,label='recommended_price'
    
    ax3.set_ylabel("Revenue ($)", color=COLOR_REVENUE, fontsize=36)
    ax3.tick_params(axis="y", labelcolor=COLOR_REVENUE, labelsize=32)
    
    ax2.legend(ax2.get_legend_handles_labels()[0]+ax3.get_legend_handles_labels()[0],ax2.get_legend_handles_labels()[1]+ax3.get_legend_handles_labels()[1],loc="best",shadow=True,prop={'size': 32})
    
    df_tab2 = pd.DataFrame({"Nett Price ($)":plot_price,
                        "Quantity (Units)":plot_quantity,
                        "Revenue ($)":plot_revenue,
                        "Recommended Price ($)":recomm_price},index=[1])
    
    st.dataframe(data=df_tab2, 
    			 width=None, 
    			 height=None,
     			 use_container_width=False
                 #,hide_index=True
    			 )
    
    st.pyplot(fig2)


with tab3:
    #st.subheader("P12M Compliance vs. Price Sensitivity")
    
    df_product_compliance_price =  get_product_compliance_price_sensitivity(session,product_selection,month_selection)
    df_store_compliance_price =  get_store_compliance_price_sensitivity(session,product_selection,store_selection,month_selection)
    
    compliance = df_product_compliance_price['P12_Store_Product_Compliance_Percent_Rank']
    price_sens = df_product_compliance_price['Price_Qty_Percent_Change_Percent_Rank']
    
    compliance_percent_rank_med = df_product_compliance_price['P12_Store_Product_Compliance_Percent_Rank_Med'].iloc[0]
    price_sens_percent_rank_med = df_product_compliance_price['Price_Qty_Percent_Change_Percent_Rank_Med'].iloc[0]
    
    compliance_min = min(df_product_compliance_price['P12_Store_Product_Compliance_Percent_Rank'])-max(df_product_compliance_price['P12_Store_Product_Compliance_Percent_Rank'])*0.02
    compliance_max = max(df_product_compliance_price['P12_Store_Product_Compliance_Percent_Rank'])*1.02
    price_sens_min = min(df_product_compliance_price['Price_Qty_Percent_Change_Percent_Rank'])-max(df_product_compliance_price['Price_Qty_Percent_Change_Percent_Rank'])*0.02
    price_sens_max = max(df_product_compliance_price['Price_Qty_Percent_Change_Percent_Rank'])*1.02
    
    plot_compliance = df_store_compliance_price['P12_Store_Product_Compliance_Percent_Rank'].iloc[0]
    plot_price_sens = df_store_compliance_price['Price_Qty_Percent_Change_Percent_Rank'].iloc[0]
    compliance_value = df_store_compliance_price['P12_Store_Product_Compliance'].iloc[0]
    price_sens_value = df_store_compliance_price['Price_Qty_Percent_Change'].iloc[0]
    
    fig3, ax4 = plt.subplots(figsize=(20, 20))
    
    ax4.set_xlim(compliance_min, compliance_max)
    ax4.set_ylim(price_sens_min, price_sens_max)
    
    ax4.set_xticks([(compliance_percent_rank_med - compliance_min) / 2, compliance_percent_rank_med+(compliance_max - compliance_percent_rank_med)/ 2])
    ax4.set_xticklabels(['Low','High'],fontsize=32)
    
    ax4.set_yticks([(price_sens_percent_rank_med - price_sens_min) / 2, price_sens_percent_rank_med+(price_sens_max - price_sens_percent_rank_med)/ 2])
    ax4.set_yticklabels(['Low','High'],fontsize=32,rotation='vertical',va='center')
    
    ax4.set_xlabel("P12M Compliance", fontsize=36)
    ax4.set_ylabel("Price Sensitivity", fontsize=36)
    
    ax4.axvline(compliance_percent_rank_med, c='k', lw=4)
    ax4.axhline(price_sens_percent_rank_med, c='k', lw=4)
    
    ax4.scatter(compliance,price_sens, s=300, color='grey', label='other_stores')
    #sns.scatterplot(x=compliance, y=price_sens, color='grey', sizes=20, label='other_stores', ax=ax4)
    #ax4.plot(compliance,price_sens,'o',color='grey',markersize=24,label='other_stores')
    #ax4.plot(plot_compliance,plot_price_sens,'go',markersize=24,label='selected_store')
    ax4.scatter(plot_compliance,plot_price_sens,s=400,color='#00FF7F',label='selected_store')
    
    ax4.legend(loc='best', prop={'size': 32})
    
    df_tab3 = pd.DataFrame({"Compliance (%)":compliance_value,
                            "Pricing Sensitivty Measure":price_sens_value},index=[1])
    st.dataframe(data=df_tab3, 
    			 width=None, 
    			 height=None,
    			 use_container_width=False,
                 #,hide_index=True
                )
    st.pyplot(fig3)


with tab4:
    
    df_category_compliance_price =  get_category_compliance_price_sensitivity(session,product_selection,month_selection)
    df_store_category_compliance_price =  get_store_category_compliance_price_sensitivity(session,product_selection,store_selection,month_selection)
    
    category_compliance = df_category_compliance_price['P12M_Store_Category_Compliance_Percent_Rank']
    category_price_sens = df_category_compliance_price['Category_Price_Qty_Percent_Change_Percent_Rank']
    
    category_compliance_percent_rank_med = df_category_compliance_price['P12M_Store_Category_Compliance_Percent_Rank_Med'].iloc[0]
    category_price_sens_percent_rank_med = df_category_compliance_price['Category_Price_Qty_Percent_Change_Percent_Rank_Med'].iloc[0]
	#category_price_percent_rank_med = 0.5
    
    category_compliance_min = min(df_category_compliance_price['P12M_Store_Category_Compliance_Percent_Rank'])-max(df_category_compliance_price['P12M_Store_Category_Compliance_Percent_Rank'])*0.02
    category_compliance_max = max(df_category_compliance_price['P12M_Store_Category_Compliance_Percent_Rank'])*1.02
    category_price_sens_min = min(df_category_compliance_price['Category_Price_Qty_Percent_Change_Percent_Rank'])-max(df_category_compliance_price['Category_Price_Qty_Percent_Change_Percent_Rank'])*0.02
    category_price_sens_max = max(df_category_compliance_price['Category_Price_Qty_Percent_Change_Percent_Rank'])*1.02
    
    plot_category_compliance = df_store_category_compliance_price['P12M_Store_Category_Compliance_Percent_Rank'].iloc[0]
    plot_category_price_sens = df_store_category_compliance_price['Category_Price_Qty_Percent_Change_Percent_Rank'].iloc[0]
    
    category = df_store_category_compliance_price['Category'].iloc[0]
    category_compliance_value = df_store_category_compliance_price['P12M_Category_Compliance'].iloc[0]
    category_price_sens_value = df_store_category_compliance_price['Category_Price_Qty_Percent_Change'].iloc[0]
    
    fig4, ax5 = plt.subplots(figsize=(20, 20))
    
    ax5.set_xlim(category_compliance_min, category_compliance_max)
    ax5.set_ylim(category_price_sens_min, category_price_sens_max)
    
    ax5.set_xticks([(category_compliance_percent_rank_med - category_compliance_min) / 2, category_compliance_percent_rank_med+(category_compliance_max - category_compliance_percent_rank_med)/ 2])
    ax5.set_xticklabels(['Low','High'],fontsize=32)
    
    ax5.set_yticks([(category_price_sens_percent_rank_med - category_price_sens_min) / 2, category_price_sens_percent_rank_med+(category_price_sens_max - category_price_sens_percent_rank_med)/ 2])
    ax5.set_yticklabels(['Low','High'],fontsize=32,rotation='vertical',va='center')
    
	#ax5.tick_params(labelsize=22)
    ax5.set_xlabel("P12M Compliance", fontsize=36)
    ax5.set_ylabel("Price Sensitivity", fontsize=36)
	#ax5.set_title('Product Compliance vs. Pricing Quadrant ', fontsize=40)
    
    ax5.axvline(category_compliance_percent_rank_med, c='k', lw=4)
    ax5.axhline(category_price_sens_percent_rank_med, c='k', lw=4)
    
    ax5.scatter(category_compliance,category_price_sens, s=300, color='grey', label='other_stores')
	#sns.scatterplot(x=compliance, y=price_sens, color='grey', sizes=20, label='other_stores', ax=ax5)
	#ax5.plot(compliance,price_sens,'o',color='grey',markersize=24,label='other_stores')
    #ax5.plot(plot_category_compliance,plot_category_price_sens,'go',markersize=24,label='selected_store')
    ax5.scatter(plot_category_compliance,plot_category_price_sens,s=400,color='#00FF7F',label='selected_store')
    
    ax5.legend(loc='best', prop={'size': 32})
    #fig4.suptitle("Category P12M Compliance vs. Price Sensitivity", fontsize=40)
    
    df_tab4 = pd.DataFrame({"Category": category,
							"Compliance (%)":category_compliance_value,
                            "Price Sensitivity Measure":category_price_sens_value},index=[1])
    st.dataframe(data=df_tab4,
                 width=None, 
                 height=None,
                 use_container_width=True
                 #,hide_index=True, #not available in 1.22.0
                 #column_order=None, #not available in 1.22.0
    			 #column_config=None
                )
    
    st.pyplot(fig4)