function filtered_data = custom_filter(data, fs, varargin)
%custom_filter Applies a flexible set of filters to a time-series signal.
%
%   filtered_data = custom_filter(data, fs) applies a default 4th-order
%   bandpass filter (0.5-40 Hz) and a 50 Hz notch filter to the input 'data'
%   which was sampled at 'fs' Hz.
%
%   This function uses 'filtfilt' for zero-phase filtering, which is
%   critical for physiological signals as it prevents time-shifting of
%   peaks (e.g., R-peaks in ECG).
%
%   OPTIONAL NAME-VALUE PAIRS:
%
%   'FilterType': Char/String. Specifies the main filter type.
%       'bandpass' (Default)
%       'lowpass'
%       'highpass'
%       'none'     (Applies no main filter, but will still apply notch)
%
%   'LowCutoff': Numeric. The lower frequency bound for 'bandpass' or
%       'highpass' filters. (Default: 0.5 Hz)
%
%   'HighCutoff': Numeric. The upper frequency bound for 'bandpass' or
%       'lowpass' filters. (Default: 40 Hz)
%
%   'FilterOrder': Numeric. The order of the Butterworth filter. A higher
%       order gives a steeper cutoff. (Default: 4)
%
%   'ApplyNotch': Logical. Whether to apply the notch filter.
%       true       (Default)
%       false
%
%   'NotchFrequency': Numeric. The center frequency of the notch filter,
%       typically 50 or 60 Hz for power-line noise. (Default: 50 Hz)
%
%   'NotchBandwidth': Numeric. The width of the notch filter. (Default: 1)
%
%   EXAMPLES:
%
%   % 1. Default: 0.5-40 Hz bandpass + 50 Hz notch
%   filtered_ecg = custom_filter(raw_ecg, 1000);
%
%   % 2. Low-pass only: 30 Hz lowpass, no notch
%   filtered_eeg = custom_filter(raw_eeg, 256, 'FilterType', 'lowpass', ...
%                                'HighCutoff', 30, 'ApplyNotch', false);
%
%   % 3. High-pass only: 1 Hz highpass + 60 Hz notch
%   filtered_sig = custom_filter(raw_sig, 500, 'FilterType', 'highpass', ...
%                                'LowCutoff', 1, 'NotchFrequency', 60);
%
%   % 4. No filter at all (pass-through):
%   filtered_data = custom_filter(raw_data, 256, 'FilterType', 'none', ...
%                                 'ApplyNotch', false);
%
%   % 5. Notch filter ONLY:
%   filtered_data = custom_filter(raw_data, 256, 'FilterType', 'none');

% --- 1. Input Parser ---
% Set up default values for all optional parameters
p = inputParser;
addRequired(p, 'data');
addRequired(p, 'fs');
addParameter(p, 'FilterType', 'bandpass', @(x) isstring(x) || ischar(x));
addParameter(p, 'LowCutoff', 0.5, @isnumeric);
addParameter(p, 'HighCutoff', 40, @isnumeric);
addParameter(p, 'FilterOrder', 4, @isnumeric);
addParameter(p, 'ApplyNotch', true, @islogical);
addParameter(p, 'NotchFrequency', 50, @isnumeric);
addParameter(p, 'NotchBandwidth', 1, @isnumeric);

% Parse the inputs from the user
parse(p, data, fs, varargin{:});

% Assign parsed variables
filterType = lower(p.Results.FilterType);
low_f = p.Results.LowCutoff;
high_f = p.Results.HighCutoff;
order = p.Results.FilterOrder;
nyquist = fs / 2;

% --- 2. Apply Main Filter (Bandpass, Lowpass, Highpass) ---

% Make sure data is double-precision for filtering
data = double(data);
filtered_data = data; % Start with the original data

switch filterType
    case 'bandpass'
        % Check for valid frequency cutoffs
        if low_f >= high_f
            error('HighCutoff (%.1f Hz) must be greater than LowCutoff (%.1f Hz).', high_f, low_f);
        end
        if high_f >= nyquist
             warning('HighCutoff (%.1f Hz) is at or above Nyquist (%.1f Hz). Adjusting to 0.98*Nyquist.', high_f, nyquist);
             high_f = nyquist * 0.98;
        end
        
        fprintf('Applying %d-order bandpass filter [%.2f - %.2f Hz]...\n', order, low_f, high_f);
        Wn = [low_f high_f] / nyquist;
        [b, a] = butter(order, Wn, 'bandpass');
        filtered_data = filtfilt(b, a, data); % Zero-phase filtering
        
    case 'lowpass'
        if high_f >= nyquist
             warning('HighCutoff (%.1f Hz) is at or above Nyquist (%.1f Hz). Adjusting to 0.98*Nyquist.', high_f, nyquist);
             high_f = nyquist * 0.98;
        end
        
        fprintf('Applying %d-order lowpass filter [Cutoff: %.2f Hz]...\n', order, high_f);
        Wn = high_f / nyquist;
        [b, a] = butter(order, Wn, 'low');
        filtered_data = filtfilt(b, a, data); % Zero-phase filtering
        
    case 'highpass'
        fprintf('Applying %d-order highpass filter [Cutoff: %.2f Hz]...\n', order, low_f);
        Wn = low_f / nyquist;
        [b, a] = butter(order, Wn, 'high');
        filtered_data = filtfilt(b, a, data); % Zero-phase filtering
        
    case 'none'
        fprintf('Main filter skipped (FilterType = ''none'').\n');
        % No filter applied, filtered_data remains the same as original data
        
    otherwise
        error('Unknown FilterType: "%s". Use "bandpass", "lowpass", "highpass", or "none".', p.Results.FilterType);
end

% --- 3. Apply Notch Filter (if requested) ---
if p.Results.ApplyNotch
    f_notch = p.Results.NotchFrequency;
    bw = p.Results.NotchBandwidth;
    
    if f_notch >= nyquist
        warning('Notch frequency (%.1f Hz) is at or above Nyquist (%.1f Hz). Skipping notch filter.', f_notch, nyquist);
    else
        fprintf('Applying notch filter at %.1f Hz...\n', f_notch);
        
        % Design notch filter
        % w0 = normalized center frequency
        % bw = normalized bandwidth at -3dB
        w0 = f_notch / nyquist;
        bw_norm = bw / nyquist;
        [b_notch, a_notch] = iirnotch(w0, bw_norm);
        
        % Apply notch filter to the *already filtered* data
        filtered_data = filtfilt(b_notch, a_notch, filtered_data);
    end
end

fprintf('Filtering complete.\n');

end