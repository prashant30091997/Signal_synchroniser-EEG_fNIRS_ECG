classdef MultiChannelViewer < matlab.apps.AppBase

    % Properties that must be specified by the user when creating the app
    properties (SetAccess = private)
        ECGData         double
        EEGTable        table
        OxyTable        table
        DeoxyTable      table
        CompiledData    struct % To hold compiledData(n)
        HRData          double % NEW: For 'HR'
        HRTimeVector    double % NEW: For 't_stmp'
        SubjectName     string = "N/A" % NEW: For Files(n).name
    end

    % Properties that the app uses to keep track of its state
    properties (Access = private)
        MainGridLayout  matlab.ui.container.GridLayout
        PlotPanel       matlab.ui.container.Panel
        ControlPanel    matlab.ui.container.Panel
        SubjectNameLabel matlab.ui.control.Label % NEW
        
        % Plotting components
        PlotGrid        matlab.ui.container.GridLayout
        PlotAxes        matlab.ui.control.UIAxes % Array to hold 39 axes
        
        PlotLines       = struct() % Struct to hold handles to all plot lines
        ThresholdLines  = struct() % Struct to hold handles for threshold lines
        MarkerLines     = struct() % Struct to hold vertical marker lines
        MarkerLabels    = struct() % Struct to hold marker text labels

        % Setup components
        EpochLengthEdit   matlab.ui.control.NumericEditField
        fs_ECGEdit        matlab.ui.control.NumericEditField
        fs_EEGEdit        matlab.ui.control.NumericEditField
        fs_fNIRSEdit      matlab.ui.control.NumericEditField
        YLim_ECGEdit      matlab.ui.control.EditField
        YLim_HREdit       matlab.ui.control.EditField % NEW
        YLim_EEGEdit      matlab.ui.control.EditField
        YLim_fNIRSEdit    matlab.ui.control.EditField
        Thresh_EEGEdit    matlab.ui.control.EditField
        Thresh_fNIRSEdit  matlab.ui.control.EditField
        ShowThreshCheck   matlab.ui.control.CheckBox
        NavigateByMarkerCheck matlab.ui.control.CheckBox
        LoadButton        matlab.ui.control.Button

        % Navigation components
        SliderPanel     matlab.ui.container.Panel % Bottom slider panel
        EpochSlider     matlab.ui.control.Slider
        EpochNumberEdit matlab.ui.control.NumericEditField
        TotalEpochsLabel  matlab.ui.control.Label
        
        % --- On-screen buttons ---
        NavButtonPanel  matlab.ui.container.Panel
        LeftNavButton   matlab.ui.control.Button
        RightNavButton  matlab.ui.control.Button
        UpNavButton     matlab.ui.control.Button
        DownNavButton   matlab.ui.control.Button
        QuitButton      matlab.ui.control.Button

        % Internal state variables
        EpochLength_s   double = 10
        fs_ECG          double = 1000
        fs_EEG          double = 256
        fs_fNIRS        double = 7.8125
        TotalEpochs     double = 1
        CurrentEpoch    double = 1
        CurrentMarkerIndex double = 1
        
        YLim_ECG        double = [-1, 1]
        YLim_HR         double = [50, 120] % NEW
        YLim_EEG        double = [-400, 400]
        YLim_fNIRS      double = [-2, 2]
        Thresh_EEG      double = [-75, 75]
        Thresh_fNIRS    double = [-0.5, 0.5]
        
        EEGNames        cell
        fNIRSNames      cell
        
        ShortMarkerNames = {'S', 'IM', 'CM', 'IR', 'CR', 'Cpt'};
    end

    properties (Access = public)
        UIFigure        matlab.ui.Figure
    end

    methods (Access = private)

        % Create the UIFigure and all components
        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100, 100, 1600, 900];
            app.UIFigure.Name = 'Multi-Channel Data Viewer';
            
            % Set the close request function
            app.UIFigure.CloseRequestFcn = @app.quitApp;

            % Main Layout: 2 rows (for name label), 2 columns
            app.MainGridLayout = uigridlayout(app.UIFigure, [2, 2]);
            app.MainGridLayout.ColumnWidth = {'9x', '1x'}; % 90% plots, 10% controls
            app.MainGridLayout.RowHeight = {'fit', '1x'}; % 'fit' for name, '1x' for content
            app.MainGridLayout.RowSpacing = 2;
            app.MainGridLayout.ColumnSpacing = 5;

            % --- 1. Plot Panel (Left) ---
            PlotSideGrid = uigridlayout(app.MainGridLayout);
            PlotSideGrid.Layout.Row = 2; 
            PlotSideGrid.Layout.Column = 1;
            PlotSideGrid.RowHeight = {'19x', '1x'}; % 95% plots, 5% slider
            PlotSideGrid.RowSpacing = 2;
            PlotSideGrid.ColumnWidth = {'1x'};
            PlotSideGrid.Padding = [5 0 5 0];

            app.PlotPanel = uipanel(PlotSideGrid);
            app.PlotPanel.Layout.Row = 1;
            app.PlotPanel.Layout.Column = 1;
            app.PlotPanel.Title = 'Signals';
            
            app.PlotGrid = uigridlayout(app.PlotPanel, [13, 3]); % NOW 13x3
            app.PlotGrid.RowSpacing = 2; 
            app.PlotGrid.ColumnSpacing = 5;
            app.PlotGrid.Padding = [5 5 5 5];
            app.PlotGrid.RowHeight = repmat({'1x'}, 13, 1);

            plot_idx = 1;
            for c = 1:3
                for r = 1:13
                    if plot_idx > 39 % NOW 39 plots
                        break;
                    end
                    ax = uiaxes(app.PlotGrid);
                    ax.Layout.Row = r;
                    ax.Layout.Column = c;
                    ax.XGrid = 'on';
                    ax.YGrid = 'on';
                    set(ax, 'XTickLabel', []); 
                    app.PlotAxes(plot_idx) = ax;
                    plot_idx = plot_idx + 1;
                end
            end 

            % Show labels only on the bottom-most plots (13, 26, 39)
            set(app.PlotAxes(13), 'XTickLabelMode', 'auto');
            set(app.PlotAxes(26), 'XTickLabelMode', 'auto');
            set(app.PlotAxes(39), 'XTickLabelMode', 'auto'); % UPDATED
            app.PlotAxes(13).XLabel.String = 'Time (s)';
            app.PlotAxes(26).XLabel.String = 'Time (s)';
            app.PlotAxes(39).XLabel.String = 'Time (s)'; % UPDATED

            % --- 1b. Slider Panel (Bottom) ---
            app.SliderPanel = uipanel(PlotSideGrid);
            app.SliderPanel.Layout.Row = 2;
            app.SliderPanel.Layout.Column = 1;
            app.SliderPanel.Title = 'Epoch Navigation Slider';
            
            SliderGrid = uigridlayout(app.SliderPanel);
            SliderGrid.Padding = [10 10 10 10];
            
            app.EpochSlider = uislider(SliderGrid, 'Limits', [1, 2], 'Value', 1, 'MajorTicks', [1, 2], 'MajorTickLabels', {'1', '2'});
            app.EpochSlider.ValueChangedFcn = @app.epochSliderCallback;
            
            % --- 2. Subject Name Label (Upper Right) ---
            app.SubjectNameLabel = uilabel(app.MainGridLayout);
            app.SubjectNameLabel.Layout.Row = 1; 
            app.SubjectNameLabel.Layout.Column = 2; 
            app.SubjectNameLabel.Text = "Subject: " + app.SubjectName;
            app.SubjectNameLabel.FontWeight = 'bold';
            app.SubjectNameLabel.HorizontalAlignment = 'right';
            app.SubjectNameLabel.FontSize = 14;

            % --- 3. Control Panel (Right) ---
            app.ControlPanel = uipanel(app.MainGridLayout);
            app.ControlPanel.Layout.Row = 2; 
            app.ControlPanel.Layout.Column = 2;
            app.ControlPanel.Title = 'Controls';
            
            % --- FIX: Changed grid to 17 rows, 16 fixed and 1 flexible ---
            ControlGrid = uigridlayout(app.ControlPanel, [17, 2]);
            ControlGrid.RowHeight = [repmat({22}, 16, 1); {'1x'}];
            ControlGrid.Padding = [5 5 5 5];
            
            % Setup Fields (Rows 1-11)
            uilabel(ControlGrid, 'Text', 'Epoch Length (s):');
            app.EpochLengthEdit = uieditfield(ControlGrid, 'numeric', 'Value', 10);
            
            uilabel(ControlGrid, 'Text', 'Fs ECG (Hz):');
            app.fs_ECGEdit = uieditfield(ControlGrid, 'numeric', 'Value', 1000);
            
            uilabel(ControlGrid, 'Text', 'Fs EEG (Hz):');
            app.fs_EEGEdit = uieditfield(ControlGrid, 'numeric', 'Value', 256);

            uilabel(ControlGrid, 'Text', 'Fs fNIRS (Hz):');
            app.fs_fNIRSEdit = uieditfield(ControlGrid, 'numeric', 'Value', 7.8125, 'Editable', 'off');
            
            uilabel(ControlGrid, 'Text', 'Y-Lim ECG [min, max]:');
            app.YLim_ECGEdit = uieditfield(ControlGrid, 'text', 'Value', '[-1, 1]');
            
            uilabel(ControlGrid, 'Text', 'Y-Lim HR [min, max]:');
            app.YLim_HREdit = uieditfield(ControlGrid, 'text', 'Value', '[50, 120]');
            
            uilabel(ControlGrid, 'Text', 'Y-Lim EEG [min, max]:');
            app.YLim_EEGEdit = uieditfield(ControlGrid, 'text', 'Value', '[-400, 400]');
            
            uilabel(ControlGrid, 'Text', 'Y-Lim fNIRS [min, max]:');
            app.YLim_fNIRSEdit = uieditfield(ControlGrid, 'text', 'Value', '[-2, 2]');

            uilabel(ControlGrid, 'Text', 'EEG Thresh [L, H]:');
            app.Thresh_EEGEdit = uieditfield(ControlGrid, 'text', 'Value', '[-75, 75]');
            
            uilabel(ControlGrid, 'Text', 'fNIRS Thresh [L, H]:');
            app.Thresh_fNIRSEdit = uieditfield(ControlGrid, 'text', 'Value', '[-0.5, 0.5]');
            
            app.ShowThreshCheck = uicheckbox(ControlGrid, 'Text', 'Show Thresholds');
            app.ShowThreshCheck.Layout.Column = [1, 2];
            
            % --- Marker Navigation Checkbox ---
            app.NavigateByMarkerCheck = uicheckbox(ControlGrid, 'Text', 'Navigate by Marker');
            app.NavigateByMarkerCheck.Layout.Column = [1, 2];
            app.NavigateByMarkerCheck.ValueChangedFcn = @app.navModeCallback;
            
            % --- Load Button (Row 14) ---
            app.LoadButton = uibutton(ControlGrid, 'Text', 'Load / Apply Settings', 'ButtonPushedFcn', @app.loadButtonCallback);
            app.LoadButton.Layout.Column = [1, 2];
            app.LoadButton.Layout.Row = 14; 
            
            % --- Epoch Navigation (Rows 15-16) ---
            uilabel(ControlGrid, 'Text', 'Epoch:', 'HorizontalAlignment', 'right');
            app.EpochNumberEdit = uieditfield(ControlGrid, 'numeric', 'Value', 1, 'Limits', [1, Inf], 'ValueChangedFcn', @app.epochNumberCallback);
            app.EpochNumberEdit.Layout.Row = 15; 
            
            app.TotalEpochsLabel = uilabel(ControlGrid, 'Text', 'of 1');
            app.TotalEpochsLabel.Layout.Row = 16; 
            app.TotalEpochsLabel.Layout.Column = [1, 2]; 
            app.TotalEpochsLabel.HorizontalAlignment = 'center';
            
            % --- Button Navigation Panel (Row 17 - NOW IN FLEXIBLE ROW) ---
            BottomControlGrid = uigridlayout(ControlGrid);
            BottomControlGrid.Layout.Row = 17; % <-- FIX: This is now the flexible '1x' row
            BottomControlGrid.Layout.Column = [1, 2];
            BottomControlGrid.RowHeight = {'fit', 'fit'};
            BottomControlGrid.ColumnWidth = {'1x'};
            
            app.NavButtonPanel = uipanel(BottomControlGrid, 'Title', 'Navigation');
            app.NavButtonPanel.Layout.Row = 1;
            app.NavButtonPanel.Layout.Column = 1;
            
            NavButtonGrid = uigridlayout(app.NavButtonPanel, [2, 3]);
            
            app.UpNavButton = uibutton(NavButtonGrid, 'Text', '^', 'ButtonPushedFcn', @app.navUpButtonPushed);
            app.UpNavButton.Layout.Row = 1;
            app.UpNavButton.Layout.Column = 2;
            
            app.LeftNavButton = uibutton(NavButtonGrid, 'Text', '<-', 'ButtonPushedFcn', @app.navLeftButtonPushed);
            app.LeftNavButton.Layout.Row = 2;
            app.LeftNavButton.Layout.Column = 1;
            
            app.DownNavButton = uibutton(NavButtonGrid, 'Text', 'v', 'ButtonPushedFcn', @app.navDownButtonPushed);
            app.DownNavButton.Layout.Row = 2;
            app.DownNavButton.Layout.Column = 2;
            
            app.RightNavButton = uibutton(NavButtonGrid, 'Text', '->', 'ButtonPushedFcn', @app.navRightButtonPushed);
            app.RightNavButton.Layout.Row = 2;
            app.RightNavButton.Layout.Column = 3;
            
            app.QuitButton = uibutton(BottomControlGrid, 'Text', 'QUIT APP', 'ButtonPushedFcn', @app.quitApp);
            app.QuitButton.Layout.Row = 2;
            app.QuitButton.Layout.Column = 1;
            app.QuitButton.FontColor = [1, 0, 0];
            
            % Initially disable navigation
            app.EpochNumberEdit.Enable = 'off';
            app.SliderPanel.Enable = 'off';
            app.NavigateByMarkerCheck.Enable = 'off';
            app.LeftNavButton.Enable = 'off';
            app.RightNavButton.Enable = 'off';
            app.UpNavButton.Enable = 'off';
            app.DownNavButton.Enable = 'off';
            app.QuitButton.Enable = 'off';
            
            % Show the figure
            app.UIFigure.Visible = 'on';
        end

        % Callback for the Load/Apply Button
        function loadButtonCallback(app, src, event)
            
            app.LoadButton.Enable = 'off';
            app.LoadButton.Text = 'Loading...';
            drawnow;
            
            try
                % --- 1. Read all settings from UI ---
                app.EpochLength_s = app.EpochLengthEdit.Value;
                app.fs_ECG = app.fs_ECGEdit.Value;
                app.fs_EEG = app.fs_EEGEdit.Value;
                app.fs_fNIRS = app.fs_fNIRSEdit.Value;
                
                try app.YLim_ECG = str2num(app.YLim_ECGEdit.Value); catch, end
                try app.YLim_HR = str2num(app.YLim_HREdit.Value); catch, end % NEW
                try app.YLim_EEG = str2num(app.YLim_EEGEdit.Value); catch, end
                try app.YLim_fNIRS = str2num(app.YLim_fNIRSEdit.Value); catch, end
                try app.Thresh_EEG = str2num(app.Thresh_EEGEdit.Value); catch, end
                try app.Thresh_fNIRS = str2num(app.Thresh_fNIRSEdit.Value); catch, end
    
                % --- 2. Initialize Plots (create line objects) ---
                % Clear all axes
                for i = 1:39 
                    cla(app.PlotAxes(i));
                end
                
                % Initialize/clear plot object handles
                app.PlotLines = struct();
                app.ThresholdLines = struct();
                app.MarkerLines = struct();
                app.MarkerLabels = struct(); % Initialize marker label struct
                
                % ECG (Plot 1)
                app.PlotAxes(1).YLabel.String = 'ECG';
                hold(app.PlotAxes(1), 'on');
                app.PlotLines.ECG = plot(app.PlotAxes(1), NaN, NaN, 'k');
                app.MarkerLines.ECG = plot(app.PlotAxes(1), NaN, NaN, 'g', 'LineWidth', 1);
                hold(app.PlotAxes(1), 'off');
                
                % NEW: HR (Plot 2)
                ax_hr = app.PlotAxes(2);
                ax_hr.YLabel.String = 'HR (bpm)';
                hold(ax_hr, 'on');
                app.PlotLines.HR = stairs(ax_hr, NaN, NaN, 'Color', [0.6 0 0.6]); % Purple
                app.MarkerLines.HR = plot(ax_hr, NaN, NaN, 'g', 'LineWidth', 1);
                hold(ax_hr, 'off');
                
                % EEG (Plots 3-23)
                app.EEGNames = app.EEGTable.Properties.VariableNames;
                app.PlotLines.EEG = gobjects(21, 1);
                app.ThresholdLines.EEG = gobjects(21, 2);
                app.MarkerLines.EEG = gobjects(21, 1);
                
                for i = 1:21
                    ax = app.PlotAxes(i + 2); % UPDATED: Offset by 2 (ECG + HR)
                    ax.YLabel.String = app.EEGNames{i};
                    hold(ax, 'on');
                    app.PlotLines.EEG(i) = plot(ax, NaN, NaN, 'k');
                    app.ThresholdLines.EEG(i,1) = plot(ax, NaN, NaN, 'r--');
                    app.ThresholdLines.EEG(i,2) = plot(ax, NaN, NaN, 'r--');
                    app.MarkerLines.EEG(i) = plot(ax, NaN, NaN, 'g', 'LineWidth', 1);
                    hold(ax, 'off');
                end
                
                % fNIRS (Plots 24-39)
                app.fNIRSNames = app.OxyTable.Properties.VariableNames;
                app.PlotLines.Oxy = gobjects(16, 1);
                app.PlotLines.Deoxy = gobjects(16, 1);
                app.ThresholdLines.fNIRS = gobjects(16, 2);
                app.MarkerLines.fNIRS = gobjects(16, 1);
                
                for i = 1:16
                    ax = app.PlotAxes(i + 23); % UPDATED: Offset by 23 (ECG + HR + EEG)
                    ax.YLabel.String = app.fNIRSNames{i};
                    hold(ax, 'on');
                    app.PlotLines.Oxy(i) = plot(ax, NaN, NaN, 'r');
                    app.PlotLines.Deoxy(i) = plot(ax, NaN, NaN, 'b');
                    app.ThresholdLines.fNIRS(i,1) = plot(ax, NaN, NaN, 'g--');
                    app.ThresholdLines.fNIRS(i,2) = plot(ax, NaN, NaN, 'g--');
                    app.MarkerLines.fNIRS(i) = plot(ax, NaN, NaN, 'g', 'LineWidth', 1);
                    hold(ax, 'off');
                    if i == 1
                        legend(ax, 'OxyHb', 'DeoxyHb', 'Location', 'northeast');
                    end
                end
                
                % --- 3. Calculate Epochs ---
                dur_ecg = length(app.ECGData) / app.fs_ECG;
                % Handle empty HR data (if pan-tompkins failed)
                if isempty(app.HRTimeVector)
                    dur_hr = dur_ecg; % Use ECG duration as a fallback
                else
                    dur_hr = app.HRTimeVector(end); % Time vector is already in seconds
                end
                dur_eeg = height(app.EEGTable) / app.fs_EEG;
                dur_fnirs = height(app.OxyTable) / app.fs_fNIRS;
                
                % Use the minimum duration of all loaded data
                total_duration_s = min([dur_ecg, dur_hr, dur_eeg, dur_fnirs]);
                app.TotalEpochs = floor(total_duration_s / app.EpochLength_s);
                
                % --- 4. Update Navigation UI ---
                app.EpochSlider.Limits = [1, app.TotalEpochs];
                if app.TotalEpochs > 1
                    app.EpochSlider.MajorTicks = round(linspace(1, app.TotalEpochs, min(10, app.TotalEpochs)));
                    app.EpochSlider.MajorTickLabels = string(round(linspace(1, app.TotalEpochs, min(10, app.TotalEpochs))));
                else
                    app.EpochSlider.MajorTicks = [1, 1];
                    app.EpochSlider.MajorTickLabels = {'1', '1'};
                end
                app.EpochNumberEdit.Limits = [1, app.TotalEpochs];
                app.TotalEpochsLabel.Text = ['of ' num2str(app.TotalEpochs)];
                
                app.CurrentEpoch = 1;
                app.CurrentMarkerIndex = 1;
                app.EpochSlider.Value = 1;
                app.EpochNumberEdit.Value = 1;
                app.NavigateByMarkerCheck.Value = false; 
                
                app.EpochNumberEdit.Enable = 'on';
                app.SliderPanel.Enable = 'on';
                app.NavigateByMarkerCheck.Enable = 'on';
                app.QuitButton.Enable = 'on';
                app.LeftNavButton.Enable = 'on';
                app.RightNavButton.Enable = 'on';
                app.UpNavButton.Enable = 'off';
                app.DownNavButton.Enable = 'off';
                
                % --- 5. Plot Epoch 1 ---
                app.updatePlotsByEpoch();
            
            catch ME
                uialert(app.UIFigure, ['Error during loading: ' ME.message], 'Loading Error');
                fprintf('Error in loadButtonCallback: %s\n', ME.message);
                disp(ME.stack(1));
            end
            
            app.LoadButton.Enable = 'on';
            app.LoadButton.Text = 'Load / Apply Settings';
        end
        
        % --- REFACTORED PLOTTING ---
        function drawPlots(app, t_start, t_end)
            
            % Robustness check: Do not plot if lines haven't been created
            if isempty(fieldnames(app.PlotLines))
                return;
            end
            
            time_lims = [t_start, t_end];
            x_ticks = floor(t_start):1:ceil(t_end);
            showThresh = app.ShowThreshCheck.Value;
            
            % --- Get Marker Info for this window ---
            marker_times = app.CompiledData.common_time_markers;
            marker_seq = app.CompiledData.com_seq;
            marker_indices = find(marker_times >= t_start & marker_times <= t_end);
            
            marker_line_X = [];
            marker_line_Y_ECG = [];
            marker_line_Y_HR = []; 
            marker_line_Y_EEG = [];
            marker_line_Y_fNIRS = [];
            label_X = [];
            label_Y_ECG = app.YLim_ECG(2); 
            label_Y_HR = app.YLim_HR(2); 
            label_Y_EEG = app.YLim_EEG(2);
            label_Y_fNIRS = app.YLim_fNIRS(2);
            label_Strings = {};
            
            if ~isempty(marker_indices)
                for k = 1:length(marker_indices)
                    idx = marker_indices(k);
                    t = marker_times(idx);
                    seq_num = marker_seq(idx);
                    
                    if seq_num >= 1 && seq_num <= length(app.ShortMarkerNames)
                        short_name = app.ShortMarkerNames{seq_num};
                    else
                        short_name = '?';
                    end
                    
                    marker_line_X = [marker_line_X, t, t, NaN];
                    marker_line_Y_ECG = [marker_line_Y_ECG, app.YLim_ECG(1), app.YLim_ECG(2), NaN];
                    marker_line_Y_HR = [marker_line_Y_HR, app.YLim_HR(1), app.YLim_HR(2), NaN]; 
                    marker_line_Y_EEG = [marker_line_Y_EEG, app.YLim_EEG(1), app.YLim_EEG(2), NaN];
                    marker_line_Y_fNIRS = [marker_line_Y_fNIRS, app.YLim_fNIRS(1), app.YLim_fNIRS(2), NaN];
                    
                    label_X = [label_X, t];
                    label_Strings{end+1} = short_name;
                end
            end
            
            % --- Delete Old Marker Labels ---
            try
                if isfield(app.MarkerLabels, 'ECG') && ~isempty(app.MarkerLabels.ECG) && all(isgraphics(app.MarkerLabels.ECG))
                    delete(app.MarkerLabels.ECG);
                end
                if isfield(app.MarkerLabels, 'EEG') && ~isempty(app.MarkerLabels.EEG) && all(isgraphics(app.MarkerLabels.EEG))
                    delete(app.MarkerLabels.EEG);
                end
                if isfield(app.MarkerLabels, 'fNIRS') && ~isempty(app.MarkerLabels.fNIRS) && all(isgraphics(app.MarkerLabels.fNIRS))
                    delete(app.MarkerLabels.fNIRS);
                end
            catch ME_delete
                 fprintf('Warning: Could not clear old marker labels. %s\n', ME_delete.message);
            end
            app.MarkerLabels = struct(); % Reset struct
            
            % --- 2. Update ECG Plot (Plot 1) ---
            fs = app.fs_ECG;
            idx_start = max(1, round(t_start * fs) + 1);
            idx_end = min(length(app.ECGData), round(t_end * fs));
            if idx_start < idx_end
                time_vec = linspace(idx_start/fs, idx_end/fs, idx_end - idx_start + 1);
                data_chunk = app.ECGData(idx_start:idx_end);
                set(app.PlotLines.ECG, 'XData', time_vec, 'YData', data_chunk);
            else
                set(app.PlotLines.ECG, 'XData', NaN, 'YData', NaN);
            end
            set(app.MarkerLines.ECG, 'XData', marker_line_X, 'YData', marker_line_Y_ECG);
            % Create new text labels
            if ~isempty(label_X)
                app.MarkerLabels.ECG = text(app.PlotAxes(1), label_X, repmat(label_Y_ECG, 1, length(label_X)), label_Strings, 'Color', 'g', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end
            set(app.PlotAxes(1), 'XLim', time_lims, 'YLim', app.YLim_ECG, 'XTick', x_ticks);
            
            % --- 3. Update HR Plot (Plot 2) ---
            if ~isempty(app.HRTimeVector)
                t_data_hr = app.HRTimeVector;
                hr_data = app.HRData;
                idx_start_hr = find(t_data_hr >= t_start, 1, 'first');
                idx_end_hr = find(t_data_hr <= t_end, 1, 'last');
                
                if ~isempty(idx_start_hr) && ~isempty(idx_end_hr) && idx_start_hr <= idx_end_hr
                    % For stairs, we need to include one sample *before* to draw correctly
                    idx_start_hr_plot = max(1, idx_start_hr - 1); 
                    % We also need one sample *after* if we are not at the end
                    idx_end_hr_plot = min(length(t_data_hr), idx_end_hr + 1);
                    
                    time_chunk = t_data_hr(idx_start_hr_plot:idx_end_hr_plot);
                    data_chunk = hr_data(idx_start_hr_plot:idx_end_hr_plot);
                    set(app.PlotLines.HR, 'XData', time_chunk, 'YData', data_chunk);
                else
                    set(app.PlotLines.HR, 'XData', NaN, 'YData', NaN);
                end
            else
                 set(app.PlotLines.HR, 'XData', NaN, 'YData', NaN);
            end
            set(app.MarkerLines.HR, 'XData', marker_line_X, 'YData', marker_line_Y_HR);
            set(app.PlotAxes(2), 'XLim', time_lims, 'YLim', app.YLim_HR, 'XTick', x_ticks);

            % --- 4. Update EEG Plots (Plots 3-23) ---
            fs = app.fs_EEG;
            idx_start = max(1, round(t_start * fs) + 1);
            idx_end = min(height(app.EEGTable), round(t_end * fs));
            if ~isempty(label_X)
                app.MarkerLabels.EEG = text(app.PlotAxes(3), label_X, repmat(label_Y_EEG, 1, length(label_X)), label_Strings, 'Color', 'g', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end

            if idx_start < idx_end
                time_vec = linspace(idx_start/fs, idx_end/fs, idx_end - idx_start + 1);
                for i = 1:21
                    data_chunk = app.EEGTable{idx_start:idx_end, i};
                    set(app.PlotLines.EEG(i), 'XData', time_vec, 'YData', data_chunk);
                    set(app.MarkerLines.EEG(i), 'XData', marker_line_X, 'YData', marker_line_Y_EEG);
                    set(app.PlotAxes(i+2), 'XLim', time_lims, 'YLim', app.YLim_EEG, 'XTick', x_ticks);
                    
                    if showThresh
                        set(app.ThresholdLines.EEG(i,1), 'XData', time_lims, 'YData', [app.Thresh_EEG(1), app.Thresh_EEG(1)]);
                        set(app.ThresholdLines.EEG(i,2), 'XData', time_lims, 'YData', [app.Thresh_EEG(2), app.Thresh_EEG(2)]);
                    else
                        set(app.ThresholdLines.EEG(i,1), 'XData', NaN, 'YData', NaN);
                        set(app.ThresholdLines.EEG(i,2), 'XData', NaN, 'YData', NaN);
                    end
                end
            else
                 for i = 1:21
                    set(app.PlotLines.EEG(i), 'XData', NaN, 'YData', NaN);
                 end
            end
            
            % --- 5. Update fNIRS Plots (Plots 24-39) ---
            fs = app.fs_fNIRS;
            idx_start = max(1, round(t_start * fs) + 1);
            idx_end = min(height(app.OxyTable), round(t_end * fs));
            if ~isempty(label_X)
                app.MarkerLabels.fNIRS = text(app.PlotAxes(24), label_X, repmat(label_Y_fNIRS, 1, length(label_X)), label_Strings, 'Color', 'g', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end

            if idx_start < idx_end
                time_vec = linspace(idx_start/fs, idx_end/fs, idx_end - idx_start + 1);
                for i = 1:16
                    oxy_chunk = app.OxyTable{idx_start:idx_end, i};
                    deoxy_chunk = app.DeoxyTable{idx_start:idx_end, i};
                    set(app.PlotLines.Oxy(i), 'XData', time_vec, 'YData', oxy_chunk);
                    set(app.PlotLines.Deoxy(i), 'XData', time_vec, 'YData', deoxy_chunk);
                    set(app.MarkerLines.fNIRS(i), 'XData', marker_line_X, 'YData', marker_line_Y_fNIRS);
                    set(app.PlotAxes(i+23), 'XLim', time_lims, 'YLim', app.YLim_fNIRS, 'XTick', x_ticks);
                    
                    if showThresh
                        set(app.ThresholdLines.fNIRS(i,1), 'XData', time_lims, 'YData', [app.Thresh_fNIRS(1), app.Thresh_fNIRS(1)]);
                        set(app.ThresholdLines.fNIRS(i,2), 'XData', time_lims, 'YData', [app.Thresh_fNIRS(2), app.Thresh_fNIRS(2)]);
                    else
                        set(app.ThresholdLines.fNIRS(i,1), 'XData', NaN, 'YData', NaN);
                        set(app.ThresholdLines.fNIRS(i,2), 'XData', NaN, 'YData', NaN);
                    end
                end
            else
                for i = 1:16
                    set(app.PlotLines.Oxy(i), 'XData', NaN, 'YData', NaN);
                    set(app.PlotLines.Deoxy(i), 'XData', NaN, 'YData', NaN);
                end
            end
            
            % Update plot title
            if app.NavigateByMarkerCheck.Value
                app.PlotPanel.Title = ['Signals: Marker ' num2str(app.CurrentMarkerIndex) ' of ' num2str(length(app.CompiledData.common_time_markers))];
            else
                app.PlotPanel.Title = ['Signals: Epoch ' num2str(app.CurrentEpoch) ' of ' num2str(app.TotalEpochs)];
            end
            drawnow('limitrate'); % Ensure smooth updates
        end
        
        % --- Navigation Logic ---
        
        function updatePlotsByEpoch(app)
            t_start = (app.CurrentEpoch - 1) * app.EpochLength_s;
            t_end = app.CurrentEpoch * app.EpochLength_s;
            app.drawPlots(t_start, t_end);
        end
        
        function updatePlotsByMarker(app)
            if isempty(app.CompiledData.common_time_markers)
                 fprintf('Warning: No markers to navigate.\n');
                 app.NavigateByMarkerCheck.Value = false; % Uncheck the box
                 app.navModeCallback(app.NavigateByMarkerCheck, struct('Value', false)); % Reset UI
                return;
            end
            marker_time = app.CompiledData.common_time_markers(app.CurrentMarkerIndex);
            t_start = marker_time - (app.EpochLength_s / 2);
            t_end = marker_time + (app.EpochLength_s / 2);
            app.CurrentEpoch = floor(t_start / app.EpochLength_s) + 1;
            app.CurrentEpoch = max(1, min(app.TotalEpochs, app.CurrentEpoch)); 
            app.EpochNumberEdit.Value = app.CurrentEpoch;
            app.EpochSlider.Value = app.CurrentEpoch;
            app.drawPlots(t_start, t_end);
        end
        
        
        % --- Navigation Callbacks ---

        function navModeCallback(app, src, event)
            if event.Value == true
                % Switched TO marker navigation
                if isempty(app.CompiledData.common_time_markers)
                    fprintf('Warning: No markers loaded to navigate.\n');
                    app.NavigateByMarkerCheck.Value = false;
                    return;
                end
                app.CurrentMarkerIndex = 1;
                app.EpochSlider.Enable = 'off';
                app.EpochNumberEdit.Enable = 'off';
                app.LeftNavButton.Enable = 'off';
                app.RightNavButton.Enable = 'off';
                app.UpNavButton.Enable = 'on';
                app.DownNavButton.Enable = 'on';
                app.updatePlotsByMarker();
            else
                % Switched TO epoch navigation
                app.EpochSlider.Enable = 'on';
                app.EpochNumberEdit.Enable = 'on';
                app.LeftNavButton.Enable = 'on';
                app.RightNavButton.Enable = 'on';
                app.UpNavButton.Enable = 'off';
                app.DownNavButton.Enable = 'off';
                app.updatePlotsByEpoch();
            end
        end

        function epochSliderCallback(app, src, event)
            % If user moves slider, automatically switch to epoch mode
            if app.NavigateByMarkerCheck.Value == true
                app.NavigateByMarkerCheck.Value = false;
                app.navModeCallback(app.NavigateByMarkerCheck, struct('Value', false));
            end
            
            new_epoch = round(event.Value);
            if new_epoch ~= app.CurrentEpoch
                app.CurrentEpoch = new_epoch;
                app.EpochNumberEdit.Value = new_epoch;
                app.updatePlotsByEpoch();
            end
        end
        
        function epochNumberCallback(app, src, event)
            % If user types epoch, automatically switch to epoch mode
            if app.NavigateByMarkerCheck.Value == true
                app.NavigateByMarkerCheck.Value = false;
                app.navModeCallback(app.NavigateByMarkerCheck, struct('Value', false));
            end

            new_epoch = round(event.Value);
            if new_epoch > app.TotalEpochs
                new_epoch = app.TotalEpochs;
            elseif new_epoch < 1
                new_epoch = 1;
            end
            
            if new_epoch ~= app.CurrentEpoch
                app.CurrentEpoch = new_epoch;
                app.EpochSlider.Value = new_epoch;
                app.updatePlotsByEpoch();
            else
                % This resets the edit box if they type an invalid number
                app.EpochNumberEdit.Value = new_epoch;
            end
        end
        
        % --- Button Callbacks ---
        
        function navLeftButtonPushed(app, src, event)
             try
                % Check if load button is enabled (i.e., not loading)
                if app.LoadButton.Enable == true && app.NavigateByMarkerCheck.Value == false
                    new_epoch = max(1, app.CurrentEpoch - 1);
                    if new_epoch ~= app.CurrentEpoch
                        app.CurrentEpoch = new_epoch;
                        app.EpochSlider.Value = new_epoch;
                        app.EpochNumberEdit.Value = new_epoch;
                        app.updatePlotsByEpoch();
                    end
                end
             catch ME
                fprintf('Error in LeftButton: %s\n', ME.message);
             end
        end
        
        function navRightButtonPushed(app, src, event)
             try
                if app.LoadButton.Enable == true && app.NavigateByMarkerCheck.Value == false
                    new_epoch = min(app.TotalEpochs, app.CurrentEpoch + 1);
                    if new_epoch ~= app.CurrentEpoch
                        app.CurrentEpoch = new_epoch;
                        app.EpochSlider.Value = new_epoch;
                        app.EpochNumberEdit.Value = new_epoch;
                        app.updatePlotsByEpoch();
                    end
                end
             catch ME
                fprintf('Error in RightButton: %s\n', ME.message);
             end
        end
        
        function navUpButtonPushed(app, src, event)
            try
                if app.LoadButton.Enable == true && app.NavigateByMarkerCheck.Value == true
                    new_index = max(1, app.CurrentMarkerIndex - 1);
                    if new_index ~= app.CurrentMarkerIndex
                        app.CurrentMarkerIndex = new_index;
                        app.updatePlotsByMarker();
                    end
                end
            catch ME
                fprintf('Error in UpButton: %s\n', ME.message);
            end
        end
        
        function navDownButtonPushed(app, src, event)
            try
                if app.LoadButton.Enable == true && app.NavigateByMarkerCheck.Value == true
                    new_index = min(length(app.CompiledData.common_time_markers), app.CurrentMarkerIndex + 1);
                    if new_index ~= app.CurrentMarkerIndex
                        app.CurrentMarkerIndex = new_index;
                        app.updatePlotsByMarker();
                    end
                end
            catch ME
                fprintf('Error in DownButton: %s\n', ME.message);
            end
        end
        
        function quitApp(app, src, event)
            fprintf('Close request received. Attempting to close app...\n');
            try
                uiresume(app.UIFigure); 
                delete(app.UIFigure);
                fprintf('App closed successfully.\n');
            catch ME
                fprintf('Error during app close: %s\n', ME.message);
                disp(ME.stack(1));
            end
        end
    end

    % This is the "Constructor" - the entry point
    methods (Access = public)

        % Construct app
        function app = MultiChannelViewer(varargin)

            parser = inputParser;
            addParameter(parser, 'ECGData', []);
            addParameter(parser, 'EEGTable', table);
            addParameter(parser, 'OxyTable', table);
            addParameter(parser, 'DeoxyTable', table);
            addParameter(parser, 'CompiledData', struct);
            addParameter(parser, 'HRData', []); % NEW
            addParameter(parser, 'HRTimeVector', []); % NEW
            addParameter(parser, 'SubjectName', "N/A"); % NEW
            parse(parser, varargin{:});
            
            app.ECGData = parser.Results.ECGData;
            app.EEGTable = parser.Results.EEGTable;
            app.OxyTable = parser.Results.OxyTable;
            app.DeoxyTable = parser.Results.DeoxyTable;
            app.CompiledData = parser.Results.CompiledData;
            app.HRData = parser.Results.HRData; % NEW
            app.HRTimeVector = parser.Results.HRTimeVector; % NEW
            app.SubjectName = parser.Results.SubjectName; % NEW

            createComponents(app)
            registerApp(app, app.UIFigure)

            if nargout == 0
                waitfor(app.UIFigure);
            end
        end
    end
end