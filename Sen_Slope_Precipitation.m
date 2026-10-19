clear;
clc;

%% === 1. Read the reference file and obtain spatial reference information ===
fprintf('Reading precipitation (PRE) reference data...\n');

first_file = 'YOUR_PRE_DATA_PATH/2001_sum.tif'; 

try
    [A, R] = geotiffread(first_file);
    hasGeo = 1;
    fprintf('Spatial reference information successfully loaded.\n');
catch
    A = imread(first_file, 1);
    hasGeo = 0;
    R = [];
    fprintf('Warning: spatial reference information could not be loaded. The output will be saved as an ordinary TIFF.\n');
end

if ndims(A) == 3
    A = A(:, :, 1);
end
[m, n] = size(A);
fprintf('Data dimensions: %d rows x %d columns\n', m, n);

cd = 21;  % 2001-2021, 21 years

%% === 2. Load annual precipitation data for all years ===
datasum = zeros(m * n, cd) + NaN;
p = 1;
for year = 2001:2021
    % Match the annual filename format: year_sum.tif
    filename = ['YOUR_PRE_DATA_PATH/', int2str(year), '_sum.tif']; 
    
    if ~exist(filename, 'file')
        error('File not found: %s\nPlease check the file path and filename.', filename);
    end
    
    data = imread(filename, 1);
    if ndims(data) == 3
        data = data(:, :, 1);
    end
    data = double(data);
    
    % Remove invalid background values
    data(data < 0 | data > 20000) = NaN;
    
    % Reshape into a column vector and store in the data matrix
    datasum(:, p) = reshape(data, m * n, 1);
    fprintf('Loaded: %d_sum.tif\n', year);
    p = p + 1;
end

%% === 3. Calculate pixel-wise Sen's slope ===
fprintf('\nCalculating Sen''s slope for precipitation...\n');
sen_result = zeros(m * n, 1) + NaN;

for i = 1:size(datasum, 1)
    % Display progress every 100,000 pixels
    if mod(i, 100000) == 0
        fprintf('Progress: %.1f%%\n', i/size(datasum,1)*100);
    end
    
    data = datasum(i, :);
    
    % Retain pixels with at least 3 valid annual observations
    if sum(~isnan(data)) >= 3
        slopes = [];
        
        % Calculate slopes for all possible pairs of years
        for k = 2:cd
            for j = 1:(k - 1)
                cz = data(k) - data(j);
                jl = k - j; % Time interval
                slopes = [slopes; cz / jl];
            end
        end
        
        % Use the median slope as the Sen's slope
        sen_result(i) = median(slopes);
    end
end

% Reshape the one-dimensional result into a two-dimensional raster
sen_result = reshape(sen_result, m, n);

%% === 4. Save the final Sen's slope result ===
fprintf('\nSaving the Sen''s slope result...\n');
output_folder = 'YOUR_OUTPUT_PATH/';
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

output_file = [output_folder, 'PRE_Sen_slope.tif'];

if hasGeo == 1
    geotiffwrite(output_file, single(sen_result), R);
    fprintf('Precipitation trend slope saved to:\n%s\n', output_file);
else
    imwrite(uint8((sen_result-nanmin(sen_result(:)))/nanmax(sen_result(:))*255), output_file);
    fprintf('Output saved as an ordinary TIFF without spatial reference information.\n');
end
