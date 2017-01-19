# EEG Seizure Prediction
Gareth Paul Jones  
3rd place [Melbourne University AES/MathWorks/NIH Seizure Prediction](http://blog.kaggle.com/2017/01/10/seizure-prediction-competition-3rd-place-winners-interview-gareth-jones/)  
2016

## Description
This code is designed to process the raw data from [Melbourne University AES/MathWorks/NIH Seizure Prediction](https://www.kaggle.com/c/melbourne-university-seizure-prediction), train a seizureModel (**train.m**), then predict seizure occurrence from a new test set (**predict.m**).

**train.m** script:
 - Processes raw data
	- Creates new test set from original test and training sets
 - Extracts features and saves in featuresObject (*featuresTrain*)
 - Trains an SVM and RUS boosted tree ensemble, saves the compact version of these.

**predict.m** script:
 - Loads trained models (SVM and tree ensemble saved as seizureModel objects)
 - Loads new data
   - Extracts features and saves in a featuresObject (*featuresTest*) 
 - Predicts new data
   - Reduces epoch predictions to segment predictions
   - Ensembles SVM and tree ensemble
 - Saves in to .csv submission file as per Kaggle specification

## Requirements
 - Original Kaggle data or trained models
 - MATLAB 2016b:
  - Statistics and Machine Learning Toolbox


## Notes
 - If seeds are now setting correctly, should score ~0.8059 (= 2nd place)
 - Uses new version of featuresObject that holds only one dataset, rather than both train and test sets
 - All parallel processing has been removed for hold out testing
 - All figures should be suppressed in prediction stage

# Usage
Training and prediction stages can be run independently from their respective scripts, or together from **testRun.m**. If running from **testRun.m** paths need to be set in **predict.m** and **train.m** first. Warning: **testRun.m** is designed to run entirely from scratch and *deletes all .mat files from the working directory when it starts!*

Both **predict.m** and **train.m** expect the same directory structure as provided for the competition, and train.m is specifically written to handle the temporal relationships in this dataset - it would need modification to work correctly with new data.

- Set paths in **predict.m** and **train.m**
  - Set path for new test directory. Assumes 3 subjects and same structure as in Kaggle competition
  - Set path for loading trained models
- Run **train.m** then **predict.m**

Processed features and final submission file are saved in to working directory.

# Bugs
### Model feature names
The trained model used for the Kaggle entry were trained with a version of the features object that combined feature names from different epoch lengths incorrectly. This bug is left in the new version of featuresObejct included here to maintain compatibility with the trained models. When the training code is verified as working, featuresObject should be updated to correct this bug.

### *use* structure
The *use* structure, used to hold parameters specifying which feature groups to use in training, isn't saved in the seizureModel objects. It's needed to know which features to use when making new predictions, so is re-set manually in predict.m. When new training code is added, update seizureModel object to save *use* structure so it's obvious which feature groups the seizureModel used.

### Score for new models
~~**train.m** is currently producing models scoring ~0.65. Predicting from previously trained models still scores ~0.8. Need to correctly reset model params in **train.m** and check for bugs.
11/01 - Found bug, training two SVMs, should be fixed?~~  
14/01 - Now fixed, scores 0.80590 (second place)  


# To do
 - Save *use* structure in each seizureModel
 - Add feature descriptions
