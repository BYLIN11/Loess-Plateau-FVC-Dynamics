clear; 
clc; 
 
% Suppress geographic information warning messages
warning('off', 'all'); 
 
%% === 1. Paths and parameters === 
input_folder  = 'YOUR_NTL_DATA_PATH/';                  
output_folder = 'YOUR_NTL_OUTPUT_PATH/';        
 
if ~exist(output_folder, 'dir') 
    mkdir(output_folder); 
end 
 
start_year = 2001; 
end_year   = 2021; 
years      = start_year:end_year; 
cd         = length(years);                   % 21 years 
 
%% === 2. Read the 2001 reference file and spatial reference === 
first_file = sprintf('%sNTL%d.tif', input_folder, start_year); 
 
fprintf('Reading reference file: %s ...\n', first_file); 
 
if ~exist(first_file, 'file') 
    error('File not found: %s\nPlease check the data path or filename.', first_file); 
end 
 
% Read raster data and spatial reference
[A, R] = geotiffread(first_file); 
 
if ndims(A) == 3 
    A = A(:, :, 1); 
end 
 
[m, n] = size(A); 
 
fprintf('Raster dimensions: %d rows x %d columns\n', m, n); 
 
%% === 3. Load NTL data from 2001 to 2021 === 
fprintf('\n================ Loading NTL data for 2001-2021 ================\n'); 
 
datasum = zeros(m * n, cd) + NaN; 
 
for idx = 1:cd 
 
    yr = years(idx); 
 
    filename = sprintf('%sNTL%d.tif', input_folder, yr); 
 
    if ~exist(filename, 'file') 
        error('File not found: %s', filename); 
    end 
 
    data = imread(filename, 1); 
 
    if ndims(data) == 3 
        data = data(:, :, 1); 
    end 
 
    data = double(data); 
 
    %% Check raster dimensions
    [cur_m, cur_n] = size(data); 
 
    if cur_m ~= m || cur_n ~= n 
 
        fprintf('NTL%d dimensions are inconsistent; resampling...\n', yr); 
 
        data = imresize(data, [m, n], 'nearest'); 
 
    end 
 
    %% === NoData handling === 
    % Values below 0 are treated as NoData.
    % NTL = 0 represents a valid value and is retained.
    data(data < 0) = NaN; 
 
    %% === Logarithmic transformation: ln(NTL + 1) === 
    data = log(data + 1); 
 
    %% Store transformed data
    datasum(:, idx) = reshape(data, m * n, 1); 
 
    fprintf('Loaded and transformed: NTL%d.tif -> ln(NTL+1)\n', yr); 
 
end 
 
%% === 4. Construct year combinations === 
fprintf('\n================ Constructing Theil-Sen year combinations ================\n'); 
 
comb_k = []; 
comb_j = []; 
time_diff = []; 
 
for k = 2:cd 
    for j = 1:(k - 1) 
 
        comb_k = [comb_k; k]; 
        comb_j = [comb_j; j]; 
        time_diff = [time_diff; (k - j)]; 
 
    end 
end 
 
fprintf('Number of pairwise year combinations: %d\n', length(time_diff)); 
 
%% === 5. Calculate Theil-Sen slope for each pixel === 
fprintf('\n================ Calculating Theil-Sen slope of ln(NTL+1) ================\n'); 
 
sen_result = zeros(m * n, 1) + NaN; 
 
total_pixels = size(datasum, 1); 
 
for i = 1:total_pixels 
 
    if mod(i, 100000) == 0 
        fprintf('Processing progress: %.1f%%\n', ... 
            i / total_pixels * 100); 
    end 
 
    data = datasum(i, :); 
 
    %% Require at least 3 valid years
    if sum(~isnan(data)) >= 3 
 
        % Difference between each pair of years
        cz = data(comb_k) - data(comb_j); 
 
        % Pairwise temporal slopes
        slopes = cz' ./ time_diff; 
 
        % Theil-Sen slope = median of all valid slopes
        sen_result(i) = median(slopes(~isnan(slopes))); 
 
    end 
 
end 
 
%% === 6. Reshape the result into a two-dimensional raster === 
sen_result = reshape(sen_result, m, n); 
 
%% === 7. Summarize slope statistics === 
valid_sen = sen_result(~isnan(sen_result)); 
 
fprintf('\n================ NTL Sen slope statistics ================\n'); 
 
fprintf('Valid pixels = %d\n', length(valid_sen)); 
fprintf('Min    = %.6f\n', min(valid_sen)); 
fprintf('Max    = %.6f\n', max(valid_sen)); 
fprintf('Median = %.6f\n', median(valid_sen)); 
fprintf('Mean   = %.6f\n', mean(valid_sen)); 
fprintf('P95    = %.6f\n', prctile(valid_sen, 95)); 
fprintf('P99    = %.6f\n', prctile(valid_sen, 99)); 
 
%% === 8. Save the result === 
fprintf('\n================ Saving the result ================\n'); 
 
output_file = sprintf('%sNTL_2001_2021_TheilSen_lnNTL1_Slope.tif', ... 
                      output_folder); 
 
try 
 
    geotiffwrite(output_file, single(sen_result), R); 
 
    fprintf('Result exported successfully: %s\n', output_file); 
 
catch 
 
    copyfile(first_file, output_file); 
 
    t = Tiff(output_file, 'r+'); 
    write(t, single(sen_result)); 
    close(t); 
 
    fprintf('Result exported using the original header as fallback: %s\n', output_file); 
 
end 
 
fprintf('\n'); 
fprintf('Processing completed.\n'); 
fprintf('Metric: Theil-Sen slope of ln(NTL + 1)\n'); 
fprintf('Period: 2001-2021\n'); 
fprintf('Output file: %s\n', output_file);
