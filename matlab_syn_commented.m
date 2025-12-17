% --- Initialization ---
close all; % Closes all open figure windows.
clear all; % Clears all variables from the workspace.
clc;       % Clears the command window text.

% --- Setup Directories and File Lists ---
% Defines the main directory where the subject data folders are located.
mainDir = 'D:\fNIRS_EEG_project\24_07_2025\EEG_NIRx_Labchart_Superlab_Data';
cd(mainDir); % Changes the current working directory to the main data directory.
Files = dir; % Gets a list of all files and folders in the current directory.
Files = Files([Files.isdir]); % Filters the list to include only directories.
Files([1 2], :) = []; % Removes the first two entries, which are '.' (current folder) and '..' (parent folder).
% --- Pre-allocate Data Structure ---
% Initializes an empty structure with ALL fields to prevent errors.
% We must include 'common_time_markers' here, even though it's
% added later, so the struct array has the correct final shape.
compiledData = struct('folderName', {}, ...
                      'comtext', {}, ...
                      'com_seq', {}, ...
                      'com_sec_Labchart', {}, ...
                      'com_frames_fNIRS', {}, ...
                      'com_sec_EEG', {}, ...
                      'common_time_markers', {}); 
                  
response_count_percent_latency = struct('ResponseCounts', {}, ...
                         'ResponsePercentages', {}, ...
                         'AverageLatencies', {});
% --- Load Synchronization Markers ---
% Reads the marker timing information from an Excel file into a table.
Markers_EEG_fNIRs = readtable('D:\fNIRS_EEG_project\24_07_2025\Markers_EEg_fNIRs.xlsx');

t_before = 300; % time in seconda to trim all the records before first start marker
t_after = 30; % time in seconda to trim all the records after last marker
lowCutEEG  = 0.01; % low cut filter frequency for EEG in Hz
highCutEEG = 70 ;  % high cut filter frequency for EEG in Hz
lowCutfNIRS = 0.01; % low cut filter frequency for fNIRS in Hz
highCutfNIRS = 5;   % high cut filter frequency for fNIRS in Hz

show_app = 1 % wheteher to show the app or not
% Changes the current directory to the parent project folder.
cd D:\fNIRS_EEG_project
%% --- Main Loop to Process Each Folder ---
for n = 7 :  size (Files,1);
    
    % Synchronisation of EEG, ECG and fNIRS using start marker
    addpath D:\fNIRS_EEG_project
    [compiledData, deoxyHb, ECG, EDF, loadedVars, oxyHb]= signal_synchroniser(mainDir, Files, Markers_EEG_fNIRs,compiledData,n);
    % Derived EEG channels
    addpath D:\fNIRS_EEG_project
    [derivedChannelsTable, oxyHb, deoxyHb] = create_derived_channels(EDF, oxyHb, deoxyHb,  lowCutfNIRS, highCutfNIRS,lowCutEEG, highCutEEG,n);
    % trim all the records for getting a common window of interest
    addpath D:\fNIRS_EEG_project
    [trim_ECG, trim_EEG, trim_oxyHb, trim_deoxyHb, compiledData(n)] = trim_synchronized_data(oxyHb, deoxyHb, ECG, EDF, derivedChannelsTable, loadedVars, compiledData(n), t_before, t_after);
    
    % ... inside your main 'for n = ...' loop ...
    % Deriving HR from ECG
    sr_ECG = loadedVars.samplerate (3,1);
    addpath D:\fNIRS_EEG_project
       if isempty(trim_ECG)==0
              t_new = 0; 
              tic
              while  t_new < (round(size(trim_ECG,2)/sr_ECG) -2)  && toc<10
                  if t_new ==0
                [qrs_amp_raw,qrs_i_raw,delay]=pan_tompkin_ecg(trim_ECG,sr_ECG,0); % use pan_tompkin on trim_ECG data
                trial_RR =  diff(qrs_i_raw).*(1000/sr_ECG);  % differences of consecutive qrs_i_raw provides RR in ms and adding new row in man_vise_data for RR
                t_new = qrs_i_raw(end)/sr_ECG;
                trial_i_1= qrs_i_raw(1:end-1)./sr_ECG; trial_i_2 = qrs_i_raw./sr_ECG;
                  else
                      
                      t_new = t_new +1 ; % used when pan tompkin stops calculating RR interval due to very high amplitude movement artifact
                      [qrs_amp_raw,qrs_i_raw,delay]=pan_tompkin_ecg(trim_ECG(1,t_new*sr_ECG:end),sr_ECG,0);
                      trial_RR=  [trial_RR (qrs_i_raw(1,1)-t_new+1) diff(qrs_i_raw)].*(1000/sr_ECG);
                      t_new = qrs_i_raw(end)/sr_ECG;
                      trial_i_1 = [trial_i_2  qrs_i_raw(1:end-1)]./sr_ECG;  trial_i_2 = [trial_i_2  qrs_i_raw]./sr_ECG;
                  end 
                  toc
              end
           RR = trial_RR;
           HR = 60000./RR; % HR calculation and adding new row in man_vise_data for for HR
           t_stmp= trial_i_1; % time in seconds of R wave
                       
        else  
            RR= []; HR= [];
                t_stmp=[]
       end
      
    % analyse counts, percentages and latencies of correct or incorrect
    % responses to markers
    response_count_percent_latency(n) = analyze_responses(compiledData,n);
    
    
% --- All your data is loaded ---
% 'ECG' is your 1xN vector
% 'derivedChannelsTable' is your EEG table
% 'oxyHb' is your fNIRS oxy table
% 'deoxyHb' is your fNIRS deoxy table

fprintf('Opening interactive viewer for subject %s...\n', Files(n).name);

% --- This is the new part ---

trim_ECG = trim_ECG.*1000;
% 1. Create an instance of the app, passing in the data
if show_app == 1;
app_viewer = MultiChannelViewer('ECGData', trim_ECG, ...
                                'EEGTable', trim_EEG, ...
                                'OxyTable', trim_oxyHb, ...
                                'DeoxyTable', trim_deoxyHb, ...
                                'CompiledData', compiledData(n), ...
                                'HRData', HR, ...
                                'HRTimeVector', t_stmp, ...
                                'SubjectName', Files(n).name);
% 2. PAUSE the main script and wait for the app to be closed
uiwait(app_viewer.UIFigure);

% 3. When the app is closed (by pressing 'Q'), the script continues
fprintf('Viewer closed. Continuing to next subject...\n');

end

% ... end of your 'for' loop ...
end

% --- Finalization ---
% Displays a separator line in the command window for clarity.
disp('------------------------------------');
% Displays a message indicating that the data processing and compilation is complete.
disp('Data compilation finished.');
% Clears all variables from the workspace except for those needed for further analysis.
clearvars -except trim_ECG EDF Files trim_deoxyHb trim_oxyHb compiledData trim_EEG loadedVars lowCutEEG highCutEEG lowCutfNIRS highCutfNIRS response_count_percent_latency show_app
%clearvars -except ECG EDF Files deoxyHb oxyHb compiledData derivedChannelsTable loadedVars