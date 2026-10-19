// ============================================================================
// Loess Plateau FVC Dynamics
// TerraClimate Soil Moisture: July–September, 2001–2021
//
// Data source:
// TerraClimate (IDAHO_EPSCOR/TERRACLIMATE)
//
// Variable:
// Soil moisture (soil)
//
// Study period:
// 2001–2021
//
// Temporal period:
// July–September
//
// Spatial resolution:
// 4638 m
//
// Description:
// This script calculates the annual mean soil moisture for July–September
// from TerraClimate data, generates a multi-year composite soil moisture
// layer, visualizes the temporal trend, and exports annual and composite
// raster datasets.
//
// Note:
// Replace the study-area Asset ID with your own Google Earth Engine Asset
// path before running this script.
// ============================================================================


// ============================================================================
// 1. Study Area
// ============================================================================

var region = ee.FeatureCollection(
  "YOUR_GEE_ASSET_PATH/LP0510"
);

Map.centerObject(region, 6);


// ============================================================================
// 2. Load TerraClimate Dataset
// ============================================================================

var tcCollection = ee.ImageCollection("IDAHO_EPSCOR/TERRACLIMATE")
                     .filter(ee.Filter.date('2001-01-01', '2021-12-31'))
                     .filterBounds(region);


// ============================================================================
// 3. Calculate Annual Mean Soil Moisture for July–September
// ============================================================================

var years = ee.List.sequence(2001, 2021);

var yearlySMCollection = ee.ImageCollection(years.map(function(y) {

  var start = ee.Date.fromYMD(y, 7, 1);
  var end = ee.Date.fromYMD(y, 9, 30);

  var meanSm = tcCollection
                           .filterDate(start, end)
                           .select('soil')
                           .reduce(ee.Reducer.mean())
                           .float();

  var finalImg = meanSm.rename('SM_Jul_Sep');

  return finalImg.set('year', y)
                 .set(
                   'system:index',
                   ee.String(ee.Number(y).format('%d'))
                 )
                 .set(
                   'system:time_start',
                   ee.Date.fromYMD(y, 1, 1).millis()
                 );
}));


// ============================================================================
// 4. Clip Soil Moisture Data to the Study Area
// ============================================================================

var clip_SM = yearlySMCollection.map(function(img) {
  return img.clip(region);
});


// ============================================================================
// 5. Visualization Settings
// ============================================================================

var palettes = require('users/gena/packages:palettes');

var smVis = {
  min: 10,
  max: 100,
  palette: palettes.colorbrewer.YlGn[9]
};


// ============================================================================
// 6. Calculate and Display the 2001–2021 Comprehensive Soil Moisture
// ============================================================================
//
// The multi-year median soil moisture is generated as the comprehensive
// soil moisture variable used for the Geodetector analysis.
// ============================================================================

var comprehensive_SM = clip_SM
  .select('SM_Jul_Sep')
  .reduce(ee.Reducer.median())
  .rename('SM_Comprehensive');

Map.addLayer(
  comprehensive_SM,
  smVis,
  '2001-2021 Comprehensive Soil Moisture (Geodetector Variable)'
);


// ============================================================================
// 7. Generate the Annual Soil Moisture Time Series
// ============================================================================

var Yearly_Chart = ui.Chart.image.series({

  imageCollection: clip_SM.select("SM_Jul_Sep"),

  region: region,

  reducer: ee.Reducer.mean(),

  scale: 4638,

  xProperty: "year",

}).setOptions({

  interpolateNulls: true,

  lineWidth: 2,

  pointSize: 3,

  title: "July–September Mean Soil Moisture (2001–2021)",

  vAxis: {
    title: "July–September Mean Soil Moisture (mm)"
  },

  hAxis: {
    title: "Year",
    format: '####'
  },

  trendlines: {
    0: {
      title: "Linear Trend",
      type: "linear",
      showR2: true,
      color: "blue",
      visibleInLegend: true
    }
  }

});

print(Yearly_Chart);


// ============================================================================
// 8. Define the Image Export Function
// ============================================================================

function exportImage(image, regionGeo, fileName) {

  Export.image.toDrive({

    image: image,

    description: "Drive-" + fileName,

    fileNamePrefix: fileName,

    folder: "Region_SM_Jul_Sep_2001_2021",

    scale: 4638,

    region: regionGeo,

    maxPixels: 1e13,

    crs: "EPSG:4326"

  });
}


// ============================================================================
// 9. Export Annual Soil Moisture Images for 2001–2021
// ============================================================================

var indexList = clip_SM
  .reduceColumns(
    ee.Reducer.toList(),
    ["system:index"]
  )
  .get("list");

indexList.evaluate(function(indexs) {

  for (var i = 0; i < indexs.length; i++) {

    var yearStr = indexs[i];

    var image = clip_SM
      .filter(ee.Filter.eq("system:index", yearStr))
      .first();

    exportImage(
      image.select('SM_Jul_Sep'),
      region.geometry(),
      "SM_Jul_Sep_" + yearStr
    );
  }

});


// ============================================================================
// 10. Export the 2001–2021 Comprehensive Soil Moisture Layer
// ============================================================================

Export.image.toDrive({

  image: comprehensive_SM,

  description: "Drive-Comprehensive_SM_2001_2021",

  fileNamePrefix: "Comprehensive_SM_2001_2021",

  folder: "Region_SM_Jul_Sep_2001_2021",

  scale: 4638,

  region: region.geometry(),

  maxPixels: 1e13,

  crs: "EPSG:4326"

});


// ============================================================================
// 11. Calculate and Export Annual Regional Mean Soil Moisture
// ============================================================================

var table = ee.FeatureCollection(
  clip_SM.map(function(image) {

    var date = image.get("year");

    return ee.Feature(null, {

      "year": date,

      "SM_Jul_Sep_mean":
        image.reduceRegion(
          ee.Reducer.mean(),
          region,
          4638
        ).get("SM_Jul_Sep")

    });

  })
);


Export.table.toDrive({

  collection: table,

  description: "Yearly_SM_Jul_Sep_Table",

  folder: "Region_SM_Jul_Sep_2001_2021",

  fileNamePrefix: "Region_SM_Jul_Sep_Yearly_Table_2001_2021",

  fileFormat: "CSV"

});


// ============================================================================
// End of Script
// ============================================================================
