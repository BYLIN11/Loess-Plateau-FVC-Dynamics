clear
clc

%% ==================== Read Data ====================

MeanFVC = double(imread('YOUR_DATA_PATH/FVC_MEAN.tif'));
max(MeanFVC(:))
Zone = imread('YOUR_DATA_PATH/AI_calss.tif');

%% ==================== Extract Data for Three Aridity Zones ====================

Arid      = MeanFVC(Zone==1);
SemiArid  = MeanFVC(Zone==2);
SubHumid  = MeanFVC(Zone==3);

%% Remove all invalid values
Arid = Arid(isfinite(Arid));
SemiArid = SemiArid(isfinite(SemiArid));
SubHumid = SubHumid(isfinite(SubHumid));

Arid = Arid(Arid>=0 & Arid<=1);
SemiArid = SemiArid(SemiArid>=0 & SemiArid<=1);
SubHumid = SubHumid(SubHumid>=0 & SubHumid<=1);

Arid     = Arid(~isnan(Arid));
SemiArid = SemiArid(~isnan(SemiArid));
SubHumid = SubHumid(~isnan(SubHumid));

FVC = [Arid;
       SemiArid;
       SubHumid];

Group = [...
    repmat({'Arid'},length(Arid),1);
    repmat({'Semi-arid'},length(SemiArid),1);
    repmat({'Sub-humid'},length(SubHumid),1)];

%% ==================== Plot ====================

figure('Color','w','Position',[300 200 560 430])

boxplot(FVC,Group,...
    'Symbol','',...          % Do not display outliers
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
          'EdgeColor',color(k,:),...
          'LineWidth',1.5);

end

%% ==================== Mean Values ====================

meanValue = [mean(Arid),...
             mean(SemiArid),...
             mean(SubHumid)];

scatter(1:3,...
        meanValue,...
        90,...
        'd',...
        'MarkerEdgeColor','k',...
        'MarkerFaceColor','w',...
        'LineWidth',1.5);

%% ==================== Axes ====================

ylabel('Multi-year mean FVC',...
    'FontName','Times New Roman',...
    'FontSize',13,...
    'FontWeight','bold');

xlabel('Aridity zone',...
    'FontName','Times New Roman',...
    'FontSize',13,...
    'FontWeight','bold');

ylim([0 1])

set(gca,...
    'FontName','Times New Roman',...
    'FontSize',12,...
    'LineWidth',1.0);

grid on
ax = gca;
ax.YGrid='off';
ax.XGrid='off';
ax.GridAlpha=0.25;

box off

%% ==================== Panel Label ====================

text(0.02,...
    0.98,...
    '(a)',...
    'Units','normalized',...
    'FontWeight','bold',...
    'FontName','Times New Roman',...
    'FontSize',14,...
    'VerticalAlignment','top');

hold off

%% Output Mean Values
fprintf('Arid Mean = %.6f\n', mean(Arid));
fprintf('Semi-arid Mean = %.6f\n', mean(SemiArid));
fprintf('Sub-humid Mean = %.6f\n', mean(SubHumid));

fprintf('\n========== Mean FVC ==========\n');
fprintf('Arid       : %.4f\n', mean(Arid));
fprintf('Semi-arid  : %.4f\n', mean(SemiArid));
fprintf('Sub-humid  : %.4f\n', mean(SubHumid));
fprintf('==============================\n');
