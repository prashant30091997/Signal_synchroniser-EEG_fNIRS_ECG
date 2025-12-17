function [derivedChannelsTable, oxyHb, deoxyHb] = create_derived_channels(EDF, oxyHb, deoxyHb, lowCutfNIRS, highCutfNIRS,lowCutEEG, highCutEEG, n)
%create_derived_channels_function Creates virtual EEG channels by subtraction.
%
%   derivedChannels = create_derived_channels_function(EDF)
%   takes an EDF data structure (with .data and .chanlocs)
%   and creates new "virtual" channels by subtracting one electrode's
%   data from another, based on a user-defined list.
%
%   The final output is a new struct array: 'derivedChannels'
%
%     derivedChannels(i).name  % Contains the channel name (e.g., "Fp1 - F7")
%     derivedChannels(i).data  % Contains the 1xN vector of subtracted data

% --- 2. Define Your Desired Channels (THE "RECIPE") ---
%
% This is the ONLY part you need to edit.
% Add or remove strings from this cell array to define the
% "virtual channels" you want to create.
% The names must *exactly* match the names in 'EDF.chanlocs.labels'.
%
channel_definitions = { ...
    "EEGAF3 - EEGA1", "EEGFp1 - EEGA1", "EEGFp2 - EEGA2", "EEGAF4 - EEGA2"  ...
    "EEGF7 - EEGA1", "EEGF3 - EEGA1", "EEGF4 - EEGA2", "EEGF8 - EEGA2" ...
    "EEGT3 - EEGA1", "EEGC3 - EEGA1", "EEGC4 - EEGA2", "EEGT4 - EEGA2" ...
    "EEGT5 - EEGA1", "EEGP3 - EEGA1", "EEGP4 - EEGA2", "EEGT6 - EEGA2" ...
    "EEGO1 - EEGA1", "EEGO2 - EEGA2", "EEGFz - EEGCz", "EEGCz - EEGPz" ...  % You can add as many as you want
    "EEGPz - EEGOz"};

% filtering of fNIRS data
for n_ch_fNIRS = 1: size(oxyHb,2)
oxyHb (:,n_ch_fNIRS) = custom_filter(oxyHb (:,n_ch_fNIRS), 7.8125, ...
                            'FilterType', 'bandpass', 'LowCutoff', lowCutfNIRS, 'HighCutoff', highCutfNIRS, ...
                            'ApplyNotch', false); % Example for 50 Hz

deoxyHb (:,n_ch_fNIRS) = custom_filter(deoxyHb (:,n_ch_fNIRS), 7.8125, ...
                            'FilterType', 'bandpass', 'LowCutoff', lowCutfNIRS, 'HighCutoff', highCutfNIRS, ...
                            'ApplyNotch', false); % Example for 50 Hz
end

oxyHb = array2table(oxyHb); deoxyHb = array2table(deoxyHb);

oxyHb.Properties.VariableNames = ["Ch1", "Ch2", "Ch3", "Ch4"...
                                   "Ch5", "Ch6", "Ch7", "Ch8"...
                                   "Ch9", "Ch10", "Ch11", "Ch12"...
                                   "Ch13", "Ch14", "Ch15", "Ch16"];

deoxyHb.Properties.VariableNames = ["Ch1", "Ch2", "Ch3", "Ch4"...
                                   "Ch5", "Ch6", "Ch7", "Ch8"...
                                   "Ch9", "Ch10", "Ch11", "Ch12"...
                                   "Ch13", "C14", "Ch15", "Ch16"];
% --- 3. Process the Data and Create New Channels ---
fprintf('Creating derived channels...\n');

% Get a clean cell array of all available electrode names
% **NOTE**: If your chanlocs struct doesn't use '.labels', change it here.
try
    all_chan_names = {EDF.chanlocs.labels};
catch ME
    error('Could not get channel names from EDF.chanlocs.labels. Please check your struct field names.');
end


% Initialize empty cell arrays to hold data columns and names
all_data_cols = {};
all_col_names = {};

for i = 1:length(channel_definitions)
    
    current_definition = channel_definitions{i};
    
    % Split the string (e.g., "Fp1 - F7") into two parts ("Fp1" and "F7")
    names = split(current_definition, ' - ');
    
    if numel(names) ~= 2
        fprintf('Warning: Skipping invalid definition: %s\n', current_definition);
        continue;
    end
    
    name1 = names{1};
    name2 = names{2};
    
    % Find the row index for each electrode in EDF.data
    % We use strcmpi for a case-insensitive match (e.g., "fp1" matches "Fp1")
    idx1 = find(strcmpi(all_chan_names, name1));
    idx2 = find(strcmpi(all_chan_names, name2));
    
    % Check that both electrodes were successfully found
    if ~isempty(idx1) && ~isempty(idx2)
        % Both found. Perform the element-wise subtraction.
        new_data_row = EDF.data(idx1, :) - EDF.data(idx2, :);
        % filtering for data
        new_data_row = custom_filter(new_data_row, EDF.srate, ...
                            'FilterType', 'bandpass', 'LowCutoff', lowCutEEG, 'HighCutoff', highCutEEG, ...
                            'ApplyNotch', true, ...
                            'NotchFrequency', 50); % Example for 50 Hz
        % Store the results in our cell arrays
        % Data must be a COLUMN vector (Nx1) for the table
        all_data_cols{end+1} = new_data_row.'; 
        all_col_names{end+1} = current_definition;
        
        fprintf('Successfully created channel: %s\n', current_definition);
        
    else
        % One or both electrodes were not found. Print a warning.
        fprintf('Warning: Could not create channel "%s". Check electrode names.\n', current_definition);
        if isempty(idx1)
            fprintf('   > Could not find electrode: %s\n', name1);
        end
        if isempty(idx2)
            fprintf('   > Could not find electrode: %s\n', name2);
        end
    end
end

% --- 4. Create the Final Table ---
% Create the table from the collected data and names
if ~isempty(all_data_cols)
    % FIX: Convert all_col_names (a cell array of strings) to a proper string array
    derivedChannelsTable = table(all_data_cols{:}, 'VariableNames', string(all_col_names));
else
    derivedChannelsTable = table; % Create an empty table if no channels were made
end

derivedChannelsTable.Properties.VariableNames = ["AF3-A1", "Fp1-A1", "Fp2-A2", "AF4-A2"  ...
    "F7-A1", "F3-A1", "F4-A2", "F8-A2" ...
    "T3-A1", "C3-A1", "C4-A2", "T4-A2" ...
    "T5-A1", "P3-A1", "P4-A2", "T6-A2" ...
    "O1-A1", "O2-A2", "Fz-Cz", "Cz-Pz" ...  % You can add as many as you want
    "Pz-Oz"];


end 