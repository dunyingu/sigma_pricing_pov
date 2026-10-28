CREATE OR REPLACE FUNCTION PRICING.PRICE_SENSITIVITY("ARG1" ARRAY)
RETURNS FLOAT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.9'
PACKAGES = ('numpy','pandas','scikit-learn')
HANDLER = 'price_sensitivity'
AS
$$

"""
Develop a log-log linear model to measure price sensitivity.
The input is an array of price_quantity string. 
To use the function the rows of price and quantity need to be re-constructed into an array of price_quantity string. 
Each array correponds to a pricing object (e.g. Store-Product pair).
"""
import numpy as np
import pandas as pd
import sklearn
import sklearn.linear_model

def price_sensitivity(ds_y: list) -> float:
    
    #Construct a Dataframe from an array containing dates and values
    #ds_y=eval(ds_y)
    df = pd.DataFrame({'ds_y':ds_y}).ds_y.str.split('_',expand=True)
    df.columns = ["price", "quantity"]
    
    df.price = df.price.astype(float)
    df.quantity = df.quantity.astype(int)
    
    y_log = np.log((df["quantity"]+1).to_numpy().reshape(-1, 1))
    X_log = np.log((1/(df["price"])).to_numpy().reshape(-1, 1))
    
    log_linear_model = sklearn.linear_model.Lasso(alpha=0.0001,precompute=True,copy_X=False,max_iter=2024,tol=1e-1,positive=True, 
												  random_state=2024, selection='random')
    
    log_linear_model.fit(X_log,y_log)
    
    coef=log_linear_model.coef_[0]*(-1)
    price_qty_percent_change=1-1.1**(coef)
    
    return price_qty_percent_change
$$
;