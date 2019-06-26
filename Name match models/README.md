### This folder contains tools for Chinese name matching developed for record linkage applications. 

These follow a spectrum of complexity from a single transformation / similarity metric pipeline (Wubi86 -> Levenshtein similarity), 
through a logistic regression model combining seven transformation / similarity metric features, and several XGBoost classification tree 
ensembles with 10, 25, 50, or 141 features to classify pairs of names as matches or nonmatches. Each classifier outputs a score, which 
must be thresholded during record linkage to declare agreement/disagreement on names. Additional data are provided to support threshold 
selection in the form of F1 - curves and empirical cumulative density functions (ECDFs) for matching and nonmatching name pairs.

1. **name_match_models.Rdata:** Contains fitted objects to be used as classifiers for name matching

   1. `logistic_reg_7features`: Logistic regression model with seven similarity features. 
   *Recommended for large linkage problems (500,000 - 1,000,000 records per dataset)*, good tradeoff between speed and performance.
   
   1. `xgboost_10features`: XGBoost model with 10 features
   
   1. `xgboost_25features`: XGBoost model with 25 features. *Recommended for moderate sized linkage problems 
   (200,000 - 500,000 records per dataset).*
   All XGBoost models tended to marginally outperform logistic regression and single similarity metrics, and there was a very subtle 
   improvement from 10, to 25, to 50 features. The 25 feature model had comparable runtimes to the 10 feature model, and is thus 
   preferred as a balance between performance and efficiency within the set of XGBoost classifiers.
   
   1. `xgboost_50features`: XGBoost model with 50 features. *Recommended for small linkage problems (<= 200,000 records per dataset).* 
   This was the best-performing XGBoost model when runtime is not a concern.
   
   1. `xgboost_141features`: XGBoost model with 141 features
   
1. **model_F1_curves.Rdata:** Relationship between classifier score, true positives, false positives, recall, precision, and F1 score 
within validation data. Used to select name matching thresholds via `F_adjust_link()`, which uses an exact match linkage run to 
adjust the expected number of true positives and false positives at each score, and outputs a modified F1 curve with update `opt.thresh` slot
   
   1. `wbe_Fcurve`: Curve data for **W**u**b**i86 Levenshtein (**E**dit) similarity
   
   1. `logistic_reg_Fcurve`: Curve data for logistic regression model with 7 similarity features
   
   1. `xgboost_10_Fcurve`: Curve data for XGBoost model with 10 features
   
   1. `xgboost_25_Fcurve`: Curve data for XGBoost model with 25 features
   
   1. `xgboost_50_Fcurve`: Curve data for XGBoost model with 50 features
   
   1. `xgboost_141_Fcurve`: Curve data for XGBoost model with 141 features
   
1. **model_ecdfs.Rdata:** Empirical cumulative density functions for each classifier among matching and non-matching name pairs. 
Can be used to consider multiple similarity thresholds for name matching, though optimal criteria for multiple thresholds are currently
unknown. Each object contains slots for matches (`m_ecdf`) and nonmatches (`u_ecdf`). 
Function `fit.ecdf.red()` can be used to get predicted ECDFs, for each layer, which can then be used to estimate proportions of false 
and true positives above potential thresholds using `TP = p.m * (1 - predicted_ecdf(t))` and `FP = (1 - p.m) * (1 - predicted_ecdf(t))`.

   1. `wbe_ecdfs`: ECDF data for **W**u**b**i86 Levenshtein (**E**dit) similarity
   
   1. `logistic_reg_ecdfs`: ECDF data for logistic regression model with 7 similarity features
   
   1. `xgboost_10_ecdfs`: ECDF data for XGBoost model with 10 features
   
   1. `xgboost_25_ecdfs`: ECDF data for XGBoost model with 25 features
   
   1. `xgboost_50_ecdfs`: ECDF data for XGBoost model with 50 features
   
   1. `xgboost_141_ecdfs`: ECDF data for XGBoost model with 141 features


# Model performance on test data (excluding exact matches)

## Early recovery portion of ROC curve
![Early recovery portion of ROC curve](https://github.com/OPTI-SURVEIL/RLManual/blob/master/images/ROCE_test.png)

## Full ROC Curve
![Full ROC Curve](https://github.com/OPTI-SURVEIL/RLManual/blob/master/images/ROC_test.png)

# Projected model runtimes (*Note that these are for a system running 24 cores in parallel!*)
![Projected runtimes](https://github.com/OPTI-SURVEIL/RLManual/blob/master/images/Runtimes.png)

