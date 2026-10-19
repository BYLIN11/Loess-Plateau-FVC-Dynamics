# Aridity‑related differences in fractional vegetation cover dynamics and factors associated with long‑term trends on the Loess Plateau, China
Repository code for manuscript reproduction

NOTE: This repository only contains analysis source scripts.
Original remote‑sensing raster datasets, geospatial boundary assets, sampling CSV tables are NOT included.
Users must download corresponding public datasets and prepare local/GEE assets prior to running any code.

## Repository file inventory

### Google Earth Engine JavaScript (*.js)
Scripts executed in Google Earth Engine web editor for remote‑sensing pre‑processing and raster time‑series generation.

1. LoessPlateau_FVC_MOD13A1.js
   Input: MOD13A1 NDVI product
   Function: Calculate growing‑season fractional vegetation cover (FVC) using Dimidiate Pixel Model; export annual FVC raster composites.
   Requirement: Update YOUR_GEE_ASSET_PATH/LP0510 to user‑owned GEE feature‑collection asset for Loess Plateau boundary.

2. SM_Jul_Sep_2001_2021.js
   Input: TerraClimate dataset
   Function: Compute July‑September annual mean soil moisture, generate multi‑year composite soil‑moisture raster; export GeoTIFF outputs.
   Requirement: Update study‑area GEE asset path.

3. SPEI3_Jul_Sep_2021.js
   Input: TerraClimate precipitation and potential evapotranspiration
   Function: Calculate 3‑month standardized precipitation‑evapotranspiration index (SPEI‑3) for July‑September; produce annual time‑series and multi‑year composite raster.
   Requirement: Update study‑area GEE asset path.

### MATLAB scripts (*.m)
Perform pixel‑wise trend computation, interannual‑variability metrics and publication‑quality boxplot visualization.

1. MK_Sen_FVC_Trend_Analysis.m
   Input: Annual FVC GeoTIFF stack
   Function: Pixel‑wise Theil‑Sen slope estimation, Mann‑Kendall significance test, trend classification, p‑value calculation; export trend rasters and text‑format statistical summary.
   Requirement: Replace YOUR_*_DATA_PATH and YOUR_*_OUTPUT_PATH with local directories.

2. Sen_Slope_Precipitation.m
   Input: Annual precipitation raster stack
   Function: Pixel‑wise Theil‑Sen slope calculation for precipitation time‑series.
   Requirement: Update local input‑output file paths.

3. Trend_ln(1+GDP).m
   Input: Annual gridded GDP raster stack
   Function: Log‑transform ln(1+GDP), compute pixel‑wise Theil‑Sen slope.
   Requirement: Update local input‑output file paths.

4. Trend_ln(1+POP).m
   Input: Annual gridded population raster stack
   Function: Log‑transform ln(1+POP), compute pixel‑wise Theil‑Sen slope.
   Requirement: Update local input‑output file paths.

5. Trend_ln(1+NTL).m
   Input: Annual nighttime‑light raster stack
   Function: Log‑transform ln(1+NTL), compute pixel‑wise Theil‑Sen slope.
   Requirement: Update local input‑output file paths.

6. Boxplot_FVC_AridityZones.m
   Input: Multi‑year mean FVC raster, aridity‑zone classification raster
   Function: Extract pixel FVC values for arid / semi‑arid / sub‑humid zones; generate formatted boxplot for multi‑year mean FVC.
   Requirement: Update local file paths.

7. Boxplot_CV_AridityZones.m
   Input: FVC coefficient‑of‑variation (CV) raster, aridity‑zone classification raster
   Function: Extract CV values for three aridity zones; generate formatted boxplot for interannual variability comparison.
   Requirement: Update local file paths.

### R script (*.R)
Geographical‑detector statistical analysis.

1. OPGD.R
   Input: LP0.csv (regular‑point sampling table containing FVC trend and all explanatory variables; NOT provided in repository)
   Dependence: R package GD (version ≥ 10.8)
   Function: Optimal‑parameters‑based geographical detector (OPGD). Execute factor detection, interaction detection, risk detection for the whole Loess Plateau and three individual aridity zones; export analysis figures as PDF.
   Requirement: Prepare LP0.csv by raster point sampling within GIS software.
