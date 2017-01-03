# EEG Seizure Prediction
Gareth Paul Jones  
3rd place [Melbourne University AES/MathWorks/NIH Seizure Prediction](https://www.kaggle.com/c/melbourne-university-seizure-prediction)  
2016

## Description
This code is designed to process and predict seizure occurrence from a new test set, trained models saved in .mat are required.

**predict.m** script:
 - Loads trained models (SVM and tree ensemble saved as seizureModel objects)
 - Loads new data
   - Extracts features and saves in a featuresObject (*featuresTest*) 
 - Predicts new data
   - Reduces epoch predictions to segment predictions
   - Ensembles SVM and tree ensemble
 - Saves in to .csv submission file as per Kaggle specification

## Requirements
MATLAB 2016b:
  - Statistics and Machine Learning Toolbox


## Notes
 - Training code isn't included yet as it needs updating (see to do)
 - **predict.m** is designed to predict from general models only (ie. not single-subject models as well, will need to create another script to handle these)
 - Uses new version of featuresObject that holds only one dataset, rather than both train and test sets
 - cvPart object is included but isn't used for predicting
 - All parallel processing removed as requested
 - All figures suppressed as request (check!)

# Usage

- Set paths in **predict.m**
  - Set path for new test directory. Assumes 3 subjects and same structure as in Kaggle competition
  - Set path for loading trained models
- Run

Processed features and final submission file are saved in to working directory.

# Bugs
### Model feature names
The trained model used for the Kaggle entry were trained with a version of the features object that combined feature names from different epoch lengths incorrectly. This bug is left in the new version of featuresObejct included here to maintain compatibility with the trained models. When the training code is added, featuresObject should be updated to correct this bug.

## *use* structure
The *use* structure, used to hold parameters specifying which feature groups to use in training, isn't saved in the seizureModel objects. It's needed to know which features to use when making new predictions, so is re-set manually in predict.m. When new training code is added, update seizureModel object to save *use* structure so it's obvious which feature groups the seizureModel used.


# To do
 - Add code for training
   - Requires updating training code to work with new featureObject
 - Save *use* structure in each seizureModel
 - Add feature descriptions