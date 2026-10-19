```javascript
// ================================================================
// SPEI-3 Calculation for the Loess Plateau
// Data source: TerraClimate
// Period: 2001-2021
// Time window: July-September
// Spatial scale: 4638 m
//
// Note:
// Replace the study-area asset path below with your own GEE asset.
// ================================================================


// 1. Define the study area
var region = ee.FeatureCollection("YOUR_GEE_ASSET_PATH/LP0510");
Map.centerObject(region, 6); 


// 2. Load the TerraClimate dataset
var tcCollection = ee.ImageCollection("IDAHO_EPSCOR/TERRACLIMATE")
                     .filter(ee.Filter.date('2001-01-01', '2021-12-31'))
                     .filterBounds(region);


// 3. Calculate cumulative D values for July-September for each year from 2001 to 2021
var years = ee.List.sequence(2001, 2021);
var yearlyDCollection = ee.ImageCollection(years.map(function(y) {
  var start = ee.Date.fromYMD(y, 7, 1);  
  var end = ee.Date.fromYMD(y, 9, 30);   
  var subCol = tcCollection.filterDate(start, end);
  
  var p_sum = subCol.select('pr').reduce(ee.Reducer.sum()).multiply(0.1);
  var pet_sum = subCol.select('pet').reduce(ee.Reducer.sum()).multiply(0.1);
  var d = p_sum.subtract(pet_sum).rename('D');
                                   
  return d.set('year', y)
          .set('system:index', ee.String(ee.Number(y).format('%d')))
          .set('system:time_start', ee.Date.fromYMD(y, 1, 1).millis());
}));


// 4. Calculate the multi-year mean and standard deviation of D
var d_Mean = yearlyDCollection.select('D').reduce(ee.Reducer.mean());
var d_Std = yearlyDCollection.select('D').reduce(ee.Reducer.stdDev());


// 5. Generate the annual SPEI-3 image collection for 2001-2021
var spei3Collection = yearlyDCollection.map(function(img) {
  var year = img.get('year');
  var d_year = img.select('D');
  var spei = d_year.subtract(d_Mean).divide(d_Std).rename('SPEI3_Sept');
  return spei.set('year', year)
             .set('system:index', img.get('system:index'))
             .set('system:time_start', img.get('system:time_start'));
});


// 6. Clip the SPEI-3 images to the study area
var clip_SPEI3 = spei3Collection.map(function(img){ 
  return img.clip(region);
});


// 7. Visualization settings
var palettes = require('users/gena/packages:palettes');
var speiVis = { 
  min: -1.5, 
  max: 1.5, 
  palette: palettes.colorbrewer.RdYlBu[11] 
};


// Calculate and display the 2001-2021 comprehensive SPEI-3
// using the multi-year median
var comprehensive_SPEI3 = clip_SPEI3.select('SPEI3_Sept').reduce(ee.Reducer.median()).rename('SPEI3_Comprehensive');
Map.addLayer(comprehensive_SPEI3, speiVis, '2001-2021 Comprehensive SPEI-3 (Geodetector Variable)');


// 8. Batch export the 21 annual SPEI-3 images
// for spatial and temporal trend analyses
function exportImage(image, regionGeo, fileName) { 
     Export.image.toDrive({ 
        image: image, 
        description: "Drive-" + fileName,
        fileNamePrefix: fileName, 
        folder: "Region_SPEI3_Sept_Final", 
        scale: 4638, 
        region: regionGeo, 
        maxPixels: 1e13, 
        crs: "EPSG:4326" 
    }); 
}

var indexList = clip_SPEI3.reduceColumns(ee.Reducer.toList(), ["system:index"]).get("list"); 
indexList.evaluate(function(indexs) { 
   for (var i = 0; i < indexs.length; i++) { 
         var yearStr = indexs[i]; 
         var image = clip_SPEI3.filter(ee.Filter.eq("system:index", yearStr)).first(); 
         exportImage(image.select('SPEI3_Sept'), region.geometry(), "SPEI3_Sept_" + yearStr); 
    } 
}); 


// Export the comprehensive 2001-2021 SPEI-3 image
Export.image.toDrive({
  image: comprehensive_SPEI3,
  description: "Drive-Comprehensive_SPEI3_2001_2021",
  fileNamePrefix: "Comprehensive_SPEI3_2001_2021",
  folder: "Region_SPEI3_Sept_Final", 
  scale: 4638, 
  region: region.geometry(), 
  maxPixels: 1e13, 
  crs: "EPSG:4326"
});


// 9. Generate the annual mean SPEI-3 time series and export the CSV table
var Yearly_Chart = ui.Chart.image.series({ 
  imageCollection: clip_SPEI3.select("SPEI3_Sept"), 
  region: region, 
  reducer: ee.Reducer.mean(), 
  scale: 4638, 
  xProperty: "year"
}).setOptions({
  title: "September SPEI-3 Time Series (2001-2021)",
  vAxis: {title: "SPEI-3"},
  hAxis: {title: "Year", format: '####'}
});
print(Yearly_Chart);

var table = ee.FeatureCollection(clip_SPEI3.map(function(image){ 
  return ee.Feature(null, {
    "year": image.get("year"),
    "SPEI3_Sept_mean": image.reduceRegion(
      ee.Reducer.mean(), 
      region, 
      4638
    ).get("SPEI3_Sept")
  });
}));

Export.table.toDrive({
  collection: table,
  description: "Yearly_SPEI3_Sept_Table",
  folder: "Region_SPEI3_Sept_Final",
  fileNamePrefix: "Region_SPEI3_Sept_Yearly_Table_2001_2021",
  fileFormat: "CSV"
});
```
