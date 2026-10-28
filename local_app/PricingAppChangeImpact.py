import streamlit as st
import numpy as np
import decimal
import pandas as pd
import PricingData
import datarobot as dr
import pandas as pd
import snowflake.connector
from snowflake.connector import SnowflakeConnection
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
import pandas as pd
import numpy as np
import os
from joblib import dump, load
from snowflake.snowpark import Session
from snowflake.snowpark.types import  VariantType, StringType, StructType, StructField, TimestampType, FloatType, BooleanType, DateType
from snowflake.snowpark.functions import col, current_timestamp
from datarobot_predict.scoring_code import ScoringCodeModel
import altair as alt
import snowflake.snowpark


@st.cache_resource
def init_connection():
    return PricingData.init_connection('sandpit')

@st.cache_data
def get_level3_categories():
    return PricingData.get_level3_categories(session)

@st.cache_data
def get_mg1_categories():
    return PricingData.get_mg1_categories(session)

@st.cache_data
def get_yearmonth_categories():
    return PricingData.get_yearmonth_categories(session)

@st.cache_data
def get_rev_gp(level_3_category, price_list):
    return PricingData.get_rev_gp(session, level_3_category, price_list)

@st.cache_data
def get_streamlit_gp(level_3_category, price_list):
    return PricingData.get_streamlit_gp(session, level_3_category, price_list)

@st.cache_data
def get_changeimpact_cents(level_3_category, price_list, mg1, yearmonth, minpremium, maxpremium, Competitor_Discount):
    return PricingData.get_changeimpact_cents(session, level_3_category, price_list, mg1, yearmonth, minpremium, maxpremium, Competitor_Discount)

@st.cache_data
def get_changeimpact_perc(level_3_category, price_list, mg1, yearmonth, minpremium, maxpremium, Competitor_Discount):
    return PricingData.get_changeimpact_perc(session, level_3_category, price_list, mg1, yearmonth, minpremium, maxpremium, Competitor_Discount)


session = init_connection()
level3_categories = get_level3_categories()
mg1_categories = get_mg1_categories()
yearmonth = get_yearmonth_categories()




with st.sidebar:
    yearmonth = st.selectbox('Year-Month', yearmonth)
    category = st.selectbox('Product Category', level3_categories)
    pricelist = st.selectbox('Price List', ['','P1', 'P2', 'P3','P4'])
    material = st.selectbox('MG1 Category', mg1_categories + '')
    perc_cents_selectbox = st.selectbox('Competitive Premium percent or $', ['', '%', '$'])
    changeimpact = ''
    if perc_cents_selectbox =='%':
        minpremium, maxpremium = st.slider('Products to Select', min_value=-0.10, max_value=0.10, step=0.01, value=(-0.10, 0.00))
        Competitor_Discount = st.slider('New Discount to Competitor', min_value=-0.50, max_value=0.50, step=0.01, value=0.00)
        if yearmonth:
            changeimpact = get_changeimpact_perc(category, pricelist, material, yearmonth, minpremium, maxpremium, Competitor_Discount)
            print('perc yearmonth')
            print(yearmonth)
    elif perc_cents_selectbox == '$':
        minpremium, maxpremium = st.slider('Products to Select', min_value=-0.10, max_value=0.10, step=0.01, value=(-0.10, 0.00))
        Competitor_Discount = st.slider('New Discount to Competitor', min_value=-0.10, max_value=0.10, step=0.01, value=0.00)
        if yearmonth:
            changeimpact = get_changeimpact_cents(category, pricelist, material, yearmonth, minpremium, maxpremium, Competitor_Discount)
            print('cents yearmonth')


if type(changeimpact) == type(pd.DataFrame()):
    st.metric('GP Impact', "${:,.0f}".format(changeimpact['P1 Impact'].sum()), delta="${:,.0f}".format(changeimpact['P1 Revenue'].sum()))
    st.bar_chart(changeimpact[['P1 Impact', 'Product Name']].sort_values(by="P1 Impact", ascending=False), x='Product Name', y='P1 Impact')
    st.write(changeimpact)
    st.dataframe(changeimpact, use_container_width=True)
    st.write(changeimpact[['P1 Impact', 'Product Name']].sort_values(by="P1 Impact", ascending=False)) 

else:
    print('Please select a Product Category, Price List and new Competiror Premium to calulcate GP Impact for.')
    'Please select a Product Category, Price List and new Competiror Premium to calulcate GP Impact for.'