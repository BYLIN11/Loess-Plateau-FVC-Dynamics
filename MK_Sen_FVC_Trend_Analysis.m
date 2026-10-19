clear; 
clc; 
 
%% === 1. Read the reference file and obtain spatial reference information ===
% The script first attempts to read the geographic reference information.
% If this fails, the spatial reference is handled as unavailable.
fprintf('Reading input data...\n'); 
 
% Read the first image band/page using imread
A = imread('YOUR_DATA_PATH/FVC_2001.tif', 1);  % Read only the first image band
% If the image contains multiple channels, use the first channel
if ndims(A) == 3 
    A = A(:, :, 1); 
end 
[m, n] = size(A); 
fprintf('Data dimensions: %d rows x %d columns\n', m, n); 
 
% Attempt to read spatial reference information
try 
    % Method 1: geotiffinfo
    info = geotiffinfo('YOUR_DATA_PATH/FVC_2001.tif'); 
    R = info.SpatialRef; 
    hasGeo = 1; 
    fprintf('Spatial reference information successfully loaded.\n'); 
catch 
    try 
        % Method 2: readgeoraster
        [~, R] = readgeoraster('YOUR_DATA_PATH/FVC_2001.tif'); 
        hasGeo = 1; 
        fprintf('Spatial reference information successfully loaded.\n'); 
    catch 
        % Method 3: spatial reference unavailable
        hasGeo = 0; 
        R = []; 
        fprintf('Warning: spatial reference information could not be loaded.\n'); 
        fprintf('Please check the original dataset projection in GIS software.\n'); 
    end 
end 
 
cd = 21;  % 2001-2021, 21 years 
 
%% === 2. Load data for all years ===
datasum = zeros(m * n, cd) + NaN; 
p = 1; 
for year = 2001:2021 
    filename = ['YOUR_DATA_PATH/FVC_', int2str(year), '.tif']; 
     
    % Read the first image band using imread
    data = imread(filename, 1); 
    if ndims(data) == 3 
        data = data(:, :, 1); 
    end 
    data = double(data); 
     
    % If the data range is 0-255, scale it to 0-1
    if max(data(:)) > 1 
        data = data / 255; 
    end 
     
    data = reshape(data, m * n, 1); 
    datasum(:, p) = data; 
    fprintf('Loaded: %s\n', filename); 
    p = p + 1; 
end 
 
%% === 3. Calculate the Mann-Kendall statistic S for each pixel ===
fprintf('Calculating the Mann-Kendall statistic...\n'); 
result = zeros(m, n) + NaN; 
 
for i = 1:size(datasum, 1) 
    if mod(i, 50000) == 0 
        fprintf('Progress: %.1f%%\n', i/size(datasum,1)*100); 
    end 
     
    data = datasum(i, :); 
     
    % Retain pixels with at least 3 valid observations
    if sum(~isnan(data)) >= 3 
        sgnsum = []; 
        for k = 2:cd 
            for j = 1:(k - 1) 
                sgn = data(k) - data(j); 
                if sgn > 0 
                    sgn = 1; 
                elseif sgn < 0 
                    sgn = -1; 
                else 
                    sgn = 0; 
                end 
                sgnsum = [sgnsum, sgn]; 
            end 
        end 
        add = sum(sgnsum); 
        result(i) = add; 
    end 
end 
 
%% === 4. Calculate the Z statistic ===
fprintf('Calculating Z statistics...\n'); 
vars = cd * (cd - 1) * (2 * cd + 5) / 18; 
zc = zeros(m, n) + NaN; 
 
sy = find(result == 0); 
zc(sy) = 0; 
 
sy = find(result > 0); 
zc(sy) = (result(sy) - 1) ./ sqrt(vars); 
 
sy = find(result < 0); 
zc(sy) = (result(sy) + 1) ./ sqrt(vars); 
 
%% === 5. Calculate the Sen's slope ===
fprintf('Calculating Sen''s slope...\n'); 
sen_result = zeros(m, n) + NaN; 
 
for i = 1:size(datasum, 1) 
    if mod(i, 50000) == 0 
        fprintf('Sen''s slope progress: %.1f%%\n', i/size(datasum,1)*100); 
    end 
     
    data = datasum(i, :); 
    if sum(~isnan(data)) >= 3 
        slopes = []; 
        for k = 2:cd 
            for j = 1:(k - 1) 
                cz = data(k) - data(j); 
                jl = k - j; 
                slopes = [slopes; cz / jl]; 
            end 
        end 
        sen_result(i) = median(slopes); 
    end 
end 
 
%% === 6. Trend classification based on statistical significance ===
% Significance threshold: p < 0.05, corresponding to |Z| > 1.96
fprintf('Generating trend classification...\n'); 
class_result = zeros(m, n) + NaN; 
 
for i = 1:(m * n) 
    if ~isnan(zc(i)) && ~isnan(sen_result(i)) 
        if abs(zc(i)) > 1.96  % Significant trend
            if sen_result(i) > 0 
                class_result(i) = 1;  % Significant increase
            else 
                class_result(i) = 3;  % Significant decrease
            end 
        else  % Non-significant trend
            if sen_result(i) > 0 
                class_result(i) = 2;  % Non-significant increase
            else 
                class_result(i) = 4;  % Non-significant decrease
            end 
        end 
    end 
end 
 
%% === 7. Save results ===
fprintf('Saving results...\n'); 
output_folder = 'YOUR_OUTPUT_PATH/'; 
if ~exist(output_folder, 'dir') 
    mkdir(output_folder); 
end 
 
% Save Z statistics, Sen's slope, and trend classification
if hasGeo == 1 
    geotiffwrite([output_folder, 'MK_Z.tif'], zc, R); 
    geotiffwrite([output_folder, 'Sen_trend.tif'], sen_result, R); 
    geotiffwrite([output_folder, 'Trend_class.tif'], class_result, R); 
    fprintf('GeoTIFF files saved with spatial reference information.\n'); 
else 
    % Save as ordinary TIFF files when spatial reference information is unavailable
    % Scale data to the 0-255 range
    zc_uint8 = uint8((zc - nanmin(zc(:))) / (nanmax(zc(:)) - nanmin(zc(:))) * 255); 
    imwrite(zc_uint8, [output_folder, 'MK_Z.tif']); 
     
    sen_uint8 = uint8((sen_result - nanmin(sen_result(:))) / (nanmax(sen_result(:)) - nanmin(sen_result(:))) * 255); 
    imwrite(sen_uint8, [output_folder, 'Sen_trend.tif']); 
     
    class_uint8 = uint8(class_result); 
    imwrite(class_uint8, [output_folder, 'Trend_class.tif']); 
    fprintf('Ordinary TIFF files saved without spatial reference information.\n'); 
    fprintf('Spatial reference can be defined manually in GIS software if required.\n'); 
end 
 
%% === 8. Summarize trend classification results ===
fprintf('\n========================================\n'); 
fprintf('   FVC Trend Statistics Summary (2001-2021)\n'); 
fprintf('========================================\n'); 
 
total_valid = sum(~isnan(class_result(:))); 
count1 = sum(class_result(:) == 1);  % Significant increase
count2 = sum(class_result(:) == 2);  % Non-significant increase
count3 = sum(class_result(:) == 3);  % Significant decrease
count4 = sum(class_result(:) == 4);  % Non-significant decrease
 
fprintf(' Significant increase     : %d  (%.2f%%)\n', count1, count1/total_valid*100); 
fprintf(' Non-significant increase : %d  (%.2f%%)\n', count2, count2/total_valid*100); 
fprintf(' Significant decrease     : %d  (%.2f%%)\n', count3, count3/total_valid*100); 
fprintf(' Non-significant decrease : %d  (%.2f%%)\n', count4, count4/total_valid*100); 
fprintf('----------------------------------------\n'); 
fprintf(' Total valid pixels       : %d\n', total_valid); 
fprintf('========================================\n'); 
 
%% === 9. Calculate and save p-values ===
fprintf('Calculating p-values...\n'); 
p_value = zeros(m, n) + NaN; 
for i = 1:(m * n) 
    if ~isnan(zc(i)) 
        % Two-sided p-value
        p_value(i) = 2 * (1 - normcdf(abs(zc(i)))); 
    end 
end 
 
% Save p-value results
geotiffwrite([output_folder, 'MK_pvalue.tif'], p_value, R); 
fprintf('P-values saved: %s\n', [output_folder, 'MK_pvalue.tif']); 
 
%% === 10. Completion ===
fprintf('\nProcessing completed.\n'); 
 
% Save statistical summary
fid = fopen([output_folder, 'statistics.txt'], 'w'); 
fprintf(fid, '=== FVC Trend Statistics Summary (2001-2021) ===\n\n'); 
fprintf(fid, 'Significant increase: %d (%.2f%%)\n', count1, count1/total_valid*100); 
fprintf(fid, 'Non-significant increase: %d (%.2f%%)\n', count2, count2/total_valid*100); 
fprintf(fid, 'Significant decrease: %d (%.2f%%)\n', count3, count3/total_valid*100); 
fprintf(fid, 'Non-significant decrease: %d (%.2f%%)\n', count4, count4/total_valid*100); 
fprintf(fid, 'Total valid pixels: %d\n', total_valid); 
fclose(fid); 
 
fprintf('\nResults saved to: %s\n', output_folder); 
