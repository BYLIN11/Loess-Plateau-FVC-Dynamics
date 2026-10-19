clear

clc

%% ==================== Read Data ====================

CV = double(imread('YOUR_DATA_PATH/CV.tif'));

Zone = imread('YOUR_DATA_PATH/AI_calss.tif');

MeanFVC = double(imread('YOUR_DATA_PATH/FVC_MEAN.tif')); % Mean FVC used to exclude extremely small denominators

%% ==================== Extract Data for Three Aridity Zones ====================

% Filtering condition: retain valid values with MeanFVC > 0.02

mask_valid = isfinite(CV) & isfinite(MeanFVC) & (MeanFVC > 0.02) & (CV >= 0);

Arid      = CV(Zone==1 & mask_valid);

SemiArid  = CV(Zone==2 & mask_valid);

SubHumid  = CV(Zone==3 & mask_valid);

CV_data = [Arid; SemiArid; SubHumid];

Group = [repmat({'Arid'},length(Arid),1);

         repmat({'Semi-arid'},length(SemiArid),1);

         repmat({'Sub-humid'},length(SubHumid),1)];

%% ==================== Plot ====================

figure('Color','w','Position',[300 200 560 430])

% Symbol,'' hides extreme outliers; the default whisker range is 1.5*IQR

hBox = boxplot(CV_data, Group,...

    'Symbol','',...          

    'Widths',0.55,...

    'Colors','k');

hold on

%% ==================== Box Fill Colors ====================

boxObj = findobj(gca,'Tag','Box');

color = [

230 190 80;      % Arid

170 210 70;      % Semi-arid

60 130 70        % Sub-humid

]/255;

for k = 1:3

    patch(get(boxObj(4-k),'XData'),...

          get(boxObj(4-k),'YData'),...

          color(k,:),...

          'FaceAlpha',0.55,...

          'EdgeColor','k',...

          'LineWidth',1.2);

end

uistack(hBox, 'top');

%% ==================== Mean Values ====================

meanValue = [mean(Arid), mean(SemiArid), mean(SubHumid)];

scatter(1:3, meanValue, 80, 'd',...

        'MarkerEdgeColor','k',...

        'MarkerFaceColor','w',...

        'LineWidth',1.5);

%% ==================== Axis Settings ====================

ylabel('Coefficient of variation',...

    'FontName','Times New Roman','FontSize',13,'FontWeight','bold');

xlabel('Aridity zone',...

    'FontName','Times New Roman','FontSize',13,'FontWeight','bold');

grid off

box off

% Set the y-axis range to 0-2.0 to provide sufficient space above the whiskers

ylim([0 2.0]); 

set(gca,'FontName','Times New Roman','FontSize',12,'LineWidth',1.0);

hold off
