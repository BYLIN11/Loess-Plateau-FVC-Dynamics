clear;
clc;

warning('off', 'all');

%% ============================================================
%  POP 2001-2020
%  Theil-Sen slope of ln(POP + 1)
%
%  Processing:
%  1. Load annual POP data from 2001 to 2020
%  2. Remove NoData and anomalous values
%  3. Retain valid POP = 0 values
%  4. Apply X = ln(POP + 1)
%  5. Calculate Theil-Sen slope
%  6. Summarize slope statistics
%  7. Export the result as GeoTIFF
%% ============================================================


%% ================== 1. Paths and parameters ==================

input_folder  = 'YOUR_POP_DATA_PATH/';
output_folder = 'YOUR_POP_OUTPUT_PATH/';

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

start_year = 2001;
end_year   = 2020;

years = start_year:end_year;
cd = length(years);

fprintf('\n');
fprintf('============================================================\n');
fprintf(' POP Theil-Sen Trend Analysis\n');
fprintf(' X = ln(POP + 1)\n');
fprintf(' Period: %d-%d\n', start_year, end_year);
fprintf('============================================================\n');


%% ================== 2. Read reference file ==================

first_file = fullfile(input_folder, ...
    sprintf('POP%d.tif', start_year));

fprintf('\nReading reference file:\n%s\n', first_file);

if ~exist(first_file, 'file')
    error('File not found: %s', first_file);
end

[A, R] = geotiffread(first_file);

if ndims(A) == 3
    A = A(:,:,1);
end

A = double(A);

[m, n] = size(A);

fprintf('Raster size: %d × %d\n', m, n);


%% ================== 3. Initialize data matrix ==================

datasum = NaN(m*n, cd);

fprintf('\n');
fprintf('============================================================\n');
fprintf('Loading POP data and performing NoData filtering\n');
fprintf('============================================================\n');


%% ================== 4. Load annual POP data ==================

for idx = 1:cd

    yr = years(idx);

    filename = fullfile(input_folder, ...
        sprintf('POP%d.tif', yr));

    fprintf('\n[%d/%d] POP%d\n', idx, cd, yr);

    if ~exist(filename, 'file')
        error('File not found: %s', filename);
    end

    %% ---------- Read raster ----------

    data = imread(filename);

    if ndims(data) == 3
        data = data(:,:,1);
    end

    data = double(data);


    %% ---------- Check raster dimensions ----------

    [cur_m, cur_n] = size(data);

    if cur_m ~= m || cur_n ~= n

        fprintf('Dimension mismatch: %d × %d → %d × %d\n', ...
            cur_m, cur_n, m, n);

        data = imresize(data, [m n], 'nearest');

    end


    %% ---------- Original data statistics ----------

    fprintf('Original Max = %.6f\n', max(data(:)));


    %% ---------- NoData filtering ----------

    % Remove negative values
    data(data < 0) = NaN;

    % Common UInt16 NoData value
    data(data == 65535) = NaN;

    % Common Int32 NoData value
    data(data == 2147483647) = NaN;

    % Treat all values greater than or equal to 65535 as anomalous
    data(data >= 65535) = NaN;


    %% ---------- Valid pixel statistics ----------

    valid_data = data(~isnan(data));

    if isempty(valid_data)

        warning('POP%d contains no valid pixels.', yr);

        continue;

    end

    fprintf('Cleaned Min    = %.6f\n', min(valid_data));
    fprintf('Cleaned Max    = %.6f\n', max(valid_data));
    fprintf('Cleaned Median = %.6f\n', median(valid_data));
    fprintf('Cleaned P95    = %.6f\n', prctile(valid_data,95));
    fprintf('Cleaned P99    = %.6f\n', prctile(valid_data,99));
    fprintf('Valid pixels   = %d\n', length(valid_data));


    %% ---------- Logarithmic transformation ----------

    % POP = 0 is retained: ln(0 + 1) = 0
    data = log(data + 1);


    %% ---------- Store transformed data ----------

    datasum(:,idx) = reshape(data, m*n, 1);

end


%% ============================================================
% 5. Construct pairwise year combinations
%% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('Constructing Theil-Sen year combinations\n');
fprintf('============================================================\n');

comb_k = [];
comb_j = [];
time_diff = [];

for k = 2:cd

    for j = 1:(k-1)

        comb_k = [comb_k; k];
        comb_j = [comb_j; j];

        time_diff = [time_diff; k-j];

    end

end

fprintf('Number of year combinations = %d\n', length(time_diff));


%% ============================================================
% 6. Calculate Theil-Sen slope for each pixel
%% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('Calculating Theil-Sen slope of ln(POP + 1)\n');
fprintf('============================================================\n');

sen_result = NaN(m*n,1);

total_pixels = m*n;

for i = 1:total_pixels

    if mod(i,100000) == 0

        fprintf('Processing progress: %.1f%%\n', ...
            i/total_pixels*100);

    end


    %% Annual data for the current pixel

    data = datasum(i,:);


    %% Require at least three valid years

    valid_num = sum(~isnan(data));

    if valid_num < 3
        continue;
    end


    %% Calculate pairwise slopes

    cz = data(comb_k) - data(comb_j);

    slopes = cz' ./ time_diff;


    %% Remove NaN values

    slopes = slopes(~isnan(slopes));


    %% Theil-Sen slope

    if ~isempty(slopes)

        sen_result(i) = median(slopes);

    end

end


%% ================== 7. Reshape the result ==================

sen_result = reshape(sen_result,m,n);


%% ============================================================
% 8. Sen slope statistics
%% ============================================================

valid_sen = sen_result(~isnan(sen_result));

fprintf('\n');
fprintf('============================================================\n');
fprintf('Theil-Sen slope statistics\n');
fprintf('============================================================\n');

fprintf('Valid pixels = %d\n', length(valid_sen));

fprintf('Min    = %.6f\n', min(valid_sen));
fprintf('Max    = %.6f\n', max(valid_sen));
fprintf('Median = %.6f\n', median(valid_sen));
fprintf('Mean   = %.6f\n', mean(valid_sen));
fprintf('P95    = %.6f\n', prctile(valid_sen,95));
fprintf('P99    = %.6f\n', prctile(valid_sen,99));


%% ============================================================
% 9. Identify extreme slope pixels
%% ============================================================

[maxSen,max_idx] = max(sen_result(:),[],'omitnan');
[minSen,min_idx] = min(sen_result(:),[],'omitnan');

[max_row,max_col] = ind2sub([m n],max_idx);
[min_row,min_col] = ind2sub([m n],min_idx);

fprintf('\n');
fprintf('============================================================\n');
fprintf('Sen slope extremes\n');
fprintf('============================================================\n');

fprintf('Maximum Sen = %.6f\n',maxSen);
fprintf('Location: Row = %d, Col = %d\n',max_row,max_col);

fprintf('\n');

fprintf('Minimum Sen = %.6f\n',minSen);
fprintf('Location: Row = %d, Col = %d\n',min_row,min_col);


%% ============================================================
% 10. Save the result
%% ============================================================

output_file = fullfile(output_folder, ...
    'POP_2001_2020_TheilSen_lnPOP1_Slope.tif');

fprintf('\n');
fprintf('============================================================\n');
fprintf('Saving the result\n');
fprintf('============================================================\n');

try

    geotiffwrite(output_file, ...
        single(sen_result), R);

    fprintf('Result exported successfully.\n%s\n',output_file);

catch

    fprintf('geotiffwrite failed. Using the original header as fallback...\n');

    copyfile(first_file,output_file);

    t = Tiff(output_file,'r+');

    write(t,single(sen_result));

    close(t);

    fprintf('Result exported successfully.\n%s\n',output_file);

end


%% ============================================================
% 11. Completion
%% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('Processing completed.\n');
fprintf('============================================================\n');

fprintf('Metric: Theil-Sen slope of ln(POP + 1)\n');
fprintf('Period: %d-%d\n',start_year,end_year);
fprintf('Output: %s\n',output_file);

fprintf('\n');
