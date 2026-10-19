clear;
clc;

% Suppress GeoTIFF tag-related warning messages
warning('off', 'all');

%% === 1. Read reference file and obtain spatial reference information ===
fprintf('Reading 2001 GDP reference data and spatial reference information...\n');

input_folder = 'YOUR_GDP_DATA_PATH/';
first_file = [input_folder, '2001GDP.tif'];

try
    [A, R] = geotiffread(first_file);
    hasGeo = 1;
    fprintf('Spatial reference information loaded successfully.\n');
catch
    A = imread(first_file, 1);
    hasGeo = 0;
    R = [];
    fprintf('Warning: spatial reference information could not be read.\n');
end

if ndims(A) == 3
    A = A(:, :, 1);
end

[m, n] = size(A);
fprintf('Reference data dimensions: %d rows x %d columns\n', m, n);

cd = 19;  % 2001-2019, 19 years

%% === 2. Load annual GDP data for 2001-2019 ===
datasum = zeros(m * n, cd) + NaN;
p = 1;

for year = 2001:2019

    filename = sprintf('%s%dGDP.tif', input_folder, year);

    if ~exist(filename, 'file')
        error('File not found: %s\nPlease check the data path and filename.', filename);
    end

    data = imread(filename, 1);

    if ndims(data) == 3
        data = data(:, :, 1);
    end

    data = double(data);

    % Align data dimensions with the reference raster if necessary
    [cur_m, cur_n] = size(data);

    if cur_m ~= m || cur_n ~= n
        fprintf('Warning: %d GDP data dimensions (%d x %d) differ from the reference. Resampling...\n', ...
            year, cur_m, cur_n);

        data = imresize(data, [m, n], 'nearest');
    end

    % Remove invalid GDP values
    data(data < 0) = NaN;

    % =========================================================
    % Logarithmic transformation: ln(X + 1)
    % X' = ln(GDP + 1)
    % =========================================================
    data_log = log(data + 1);

    % Convert to a column vector and store in the data matrix
    datasum(:, p) = reshape(data_log, m * n, 1);

    fprintf('Loaded and log-transformed GDP data: %dGDP.tif\n', year);

    p = p + 1;
end

%% === 3. Calculate Theil-Sen slope of ln(GDP + 1) for each pixel ===
fprintf('\nCalculating Theil-Sen slope of ln(GDP + 1) for 2001-2019...\n');

sen_result = zeros(m * n, 1) + NaN;

% Construct pairwise temporal index matrices
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

%% === Calculate Theil-Sen slope for each pixel ===
for i = 1:size(datasum, 1)

    if mod(i, 100000) == 0
        fprintf('Processing progress: %.1f%%\n', ...
            i / size(datasum, 1) * 100);
    end

    % ln(GDP + 1) time series from 2001 to 2019
    data = datasum(i, :);

    % Calculate the slope if at least three valid years are available
    if sum(~isnan(data)) >= 3

        % Calculate slopes for all year pairs
        cz = data(comb_k) - data(comb_j);

        slopes = cz' ./ time_diff;

        % Theil-Sen slope
        sen_result(i) = median(slopes(~isnan(slopes)));

    end
end

% Reshape the one-dimensional result into a two-dimensional raster
sen_result = reshape(sen_result, m, n);

%% === 4. Save the GDP log-transformed Sen slope GeoTIFF ===
fprintf('\nSaving the GDP log-transformed Sen slope result...\n');

output_folder = 'YOUR_GDP_OUTPUT_PATH/';

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Output filename indicating the ln(GDP + 1) transformation
output_file = [output_folder, 'GDP_log_2001_2019_Sen_slope.tif'];

if hasGeo == 1

    try
        % Method 1: Copy the original header and overwrite pixel values
        copyfile(first_file, output_file);

        t = Tiff(output_file, 'r+');
        write(t, single(sen_result));
        close(t);

        fprintf('Output written using the original GeoTIFF header.\n');

    catch

        % Method 2: Use geotiffwrite as a fallback
        geotiffwrite(output_file, ...
            single(sen_result), ...
            R, ...
            'CoordRefSysCode', 54009);

        fprintf('Output written using EPSG:54009 spatial reference.\n');

    end

    fprintf('GDP log-transformed trend slope raster saved to:\n%s\n', ...
        output_file);

else

    imwrite(uint8( ...
        (sen_result - nanmin(sen_result(:))) / ...
        nanmax(sen_result(:)) * 255), ...
        output_file);

    fprintf('Output saved as a standard TIFF without spatial reference.\n');

end

fprintf('\n============================================\n');
fprintf('Processing completed.\n');
fprintf('Transformation: X'' = ln(GDP + 1)\n');
fprintf('Trend metric: Theil-Sen slope of ln(GDP + 1)\n');
fprintf('============================================\n');
