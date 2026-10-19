```javascript
// ============================================================================
// Loess Plateau FVC Dynamics
// Annual FVC estimation using MODIS MOD13A1
//
// Study period: 2001–2021
// Spatial resolution: 500 m
// Growing season: June–September
//
// Method:
// 1. MODIS DetailedQA quality control
// 2. Growing-season median NDVI composite
// 3. NDVI scaling using the MODIS scale factor (0.0001)
// 4. FVC estimation based on the 5th and 95th NDVI percentiles
// 5. Annual FVC export as GeoTIFF
//
// FVC classes:
// < 0.2       Very Low
// 0.2–0.4     Low
// 0.4–0.6     Moderate
// 0.6–0.8     High
// ≥ 0.8       Very High
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
Map.addLayer(region, {color: 'red'}, 'Boundary');


// ============================================================================
// 2. MOD13A1 Quality Control
// ============================================================================

function maskMODISQA(img) {

    var qa = img.select('DetailedQA');

    // MODLAND QA (Bits 0–1)
    // 0 = Good Quality
    // 1 = Check Other QA
    var modlandQA = qa.bitwiseAnd(3);

    var mask = modlandQA.lte(1);

    return img.updateMask(mask);
}


// ============================================================================
// 3. FVC Calculation Function
// ============================================================================
//
// FVC is estimated using the 5th and 95th percentiles of NDVI as
// the bare-soil and full-vegetation reference values, respectively.
// ============================================================================

function calFVC(BestVI, regionGeometry, scale) {

    var num = BestVI.reduceRegion({
        reducer: ee.Reducer.percentile([5,95]),
        geometry: regionGeometry,
        scale: scale,
        maxPixels: 1e13
    });

    var min = ee.Number(num.get("NDVI_p5"));
    var max = ee.Number(num.get("NDVI_p95"));

    var greaterPart = BestVI.gt(max);
    var lessPart = BestVI.lt(min);

    var middlePart = ee.Image(1)
        .subtract(greaterPart)
        .subtract(lessPart);

    var tempf1 = BestVI.subtract(min)
        .divide(max.subtract(min));

    var FVC = ee.Image(1)
        .multiply(greaterPart)
        .add(ee.Image(0).multiply(lessPart))
        .add(tempf1.multiply(middlePart));

    return FVC.rename('FVC');
}


// ============================================================================
// 4. Year List
// ============================================================================

var yearList = ee.List.sequence(2001, 2021);
var years = yearList.getInfo();


// ============================================================================
// 5. Annual FVC Calculation and Export
// ============================================================================

function FVC_year_modis(year, roi) {

    var Date_start = ee.Date.fromYMD(year, 6, 1);
    var Date_end = ee.Date.fromYMD(year, 9, 30);

    var modisCollection = ee.ImageCollection("MODIS/061/MOD13A1")
        .filterDate(Date_start, Date_end)
        .filterBounds(roi)
        .map(maskMODISQA)
        .select('NDVI');

    var NDVI = modisCollection
        .median()
        .multiply(0.0001)
        .clip(roi)
        .rename("NDVI");

    var FVC = calFVC(NDVI, roi, 500);

    // Export annual FVC as a Cloud Optimized GeoTIFF.
    Export.image.toDrive({
        image: FVC,
        description: "LoessPlateau_FVC_" + year,
        folder: "LoessPlateau_FVC",
        fileNamePrefix: "FVC_" + year,
        scale: 500,
        region: roi,
        maxPixels: 1e13,
        fileFormat: 'GeoTIFF',
        formatOptions: {
            cloudOptimized: true,
            noData: -9999
        }
    });

    return FVC.rename("FVC");
}


// ============================================================================
// 6. Build the 2001–2021 FVC Collection
// ============================================================================

var fvcCollection = ee.ImageCollection(
    yearList.map(function(year) {

        var Date_start = ee.Date.fromYMD(year, 6, 1);
        var Date_end = ee.Date.fromYMD(year, 9, 30);

        var modisCollection = ee.ImageCollection("MODIS/061/MOD13A1")
            .filterDate(Date_start, Date_end)
            .filterBounds(region)
            .map(maskMODISQA)
            .select('NDVI');

        var NDVI = modisCollection
            .median()
            .multiply(0.0001)
            .clip(region)
            .rename("NDVI");

        var FVC = calFVC(NDVI, region, 500);

        var meanFVC = FVC.reduceRegion({
            reducer: ee.Reducer.mean(),
            geometry: region,
            scale: 500,
            maxPixels: 1e13
        }).get('FVC');

        return FVC
            .set('year', year)
            .set('mean_fvc', meanFVC);
    })
);


// ============================================================================
// 7. Display Annual FVC Classes
// ============================================================================

for (var i = 0; i < years.length; i++) {

    var year = years[i];
    var ImgFVC = FVC_year_modis(year, region);

    var FVC_rank = ImgFVC
        .where(ImgFVC.lt(0.2), 1)
        .where(ImgFVC.gte(0.2).and(ImgFVC.lt(0.4)), 2)
        .where(ImgFVC.gte(0.4).and(ImgFVC.lt(0.6)), 3)
        .where(ImgFVC.gte(0.6).and(ImgFVC.lt(0.8)), 4)
        .where(ImgFVC.gte(0.8), 5);

    var showLayer = (
        year === 2001 ||
        year === 2010 ||
        year === 2021
    );

    Map.addLayer(
        FVC_rank,
        {
            min: 1,
            max: 5,
            palette: [
                "DCDCDC",
                "FFEBCD",
                "99B718",
                "529400",
                "011301"
            ]
        },
        "MODIS_FVC_" + year,
        showLayer
    );
}


// ============================================================================
// 8. FVC Time Series
// ============================================================================

var coverageChart = ui.Chart.image.series({
    imageCollection: fvcCollection.select('FVC'),
    region: region,
    reducer: ee.Reducer.mean(),
    scale: 500,
    xProperty: 'year'
})
.setChartType('LineChart')
.setOptions({
    title: 'Loess Plateau FVC (2001-2021)',
    hAxis: {
        title: 'Year',
        format: '####'
    },
    vAxis: {
        title: 'Mean FVC'
    },
    lineWidth: 2,
    pointSize: 4,
    series: {
        0: {
            color: 'green'
        }
    }
});

print(coverageChart);


// ============================================================================
// 9. Legend
// ============================================================================

var panel = ui.Panel({
    style: {
        position: 'bottom-right',
        padding: '8px 15px'
    }
});

var legend = ui.Panel({

    widgets: [

        ui.Label(
            'MODIS FVC Level',
            {fontWeight: 'bold'}
        ),

        ui.Label(
            '1 : <0.2 Very Low',
            {color: 'DCDCDC'}
        ),

        ui.Label(
            '2 : 0.2-0.4 Low',
            {color: 'FFEBCD'}
        ),

        ui.Label(
            '3 : 0.4-0.6 Moderate',
            {color: '99B718'}
        ),

        ui.Label(
            '4 : 0.6-0.8 High',
            {color: '529400'}
        ),

        ui.Label(
            '5 : ≥0.8 Very High',
            {color: '011301'}
        )

    ],

    style: {
        backgroundColor: 'white',
        padding: '10px'
    }
});

panel.add(legend);
Map.add(panel);


// ============================================================================
// End of Script
// ============================================================================
```