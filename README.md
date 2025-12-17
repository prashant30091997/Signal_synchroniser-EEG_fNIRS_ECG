fNIRS-EEG-ECG Synchronization and Analysis Pipeline

---------------------------------------------
Explanation of script for detecting TTL signal in EEG record and inserting a marker
----------------------------------------------
detect_TTL_and_click.py

This Python script is meant to listen to a serial port (like a USB-to-TTL adapter) for data coming in and click the mouse when a certain condition is met. This is what the code does:

1. Imports and Configuration: 
The "import serial" line brings in the pyserial library so that it can handle serial communication.import pyautogui: 
This command brings in the pyautogui library, which lets you control the mouse and keyboard with code.

Configuration Constants:

SERIAL_PORT = 'COM6': This tells the computer which COM port to listen to.You would change this to match your device.BAUD_RATE = 9600: This sets how fast data can be sent.

CLICK_X = 500, CLICK_Y = 305: This tells the program the coordinates on the screen for mouse click to happen. This can be clicked on some marker in the software interface of EEG or fNIRS record.

2. State Tracking zero_count = 0: This variable counts things. It keeps track of how many times the device has sent the specific signal, which is the number 0.

3. The main() function

Setup: It tries to use the specified port and baud rate to open the serial connection.

The Loop (while True): The script goes into an infinite loop to keep an eye out for data.

Reading Data: The command data = ser.read(1) reads one byte of data at a time from the serial port.

Data Processing:

It changes the byte into an integer using ord(data) when it gets data.

It sends the signal to the console to print.

The Trigger Condition:

It checks to see if the signal it got is 0.

It adds one to zero_count if it is 0.

The Action: If zero_count is greater than 1 (which means that a 0 has been received more than once), pyautogui is triggered.click(CLICK_X, CLICK_Y) to make the mouse click at the coordinates you set.

Finally, Block makes sure that the serial port is properly closed (ser.close()) when the program ends. This stops the port from getting stuck in an open state.

In short
In short, this script waits for a device connected to COM6 to send the number 0. It counts the first time it sees a 0. Every time it sees a 0 after the first time, it automatically clicks the mouse at (500, 305) on your screen.

We have used this script to insert markers in the EEG record. It can also be used to insert markers in fNIRS and labchart (recording of ECG) records. However the hardware available for recording fNIRS and ECG was having facility to detect TTL signal. Thus we did not need this way for inserting markers in fNIRS and ECG recordings.

---------------------------------------------------------------
MATLAB project for visualising the synchronised data of EEG, fNIRS and ECG
-----------------------------------------------------------------

1. Overview

In this MATLAB project, multi-modal physiological data simultaneously captured from three distinct systems is synchronized, processed, and visualized:

LabChart: Event Markers and ECG (the "Ground Truth" for timing).

fNIRS: Concentrations of Oxy and Deoxy hemoglobin (oxyHb/deoxyHb).

EEG: Electrical activity of the brain (EDF format).

The pipeline aligns these signals using a common "Start Marker," cuts them to a predetermined time window, evaluates behavioral responses (reaction times/accuracy), conducts artifact analysis (calculating heart rate), and offers an interactive graphical user interface (GUI) for visual inspection.

2. Data Structure & Folder (CRITICAL)

Your data must be arranged precisely as indicated below in order for the code to execute automatically.

Suggested Directory Structure

Make a primary project folder, such as D:\fNIRS_EEG_project.

D:\fNIRS_EEG_project\  <-- (Root Directory: Save all MATLAB codes here)
│
├── matlab_sync_commented.m            (Main Script)
├── create_derived_channels_function.m (Function)
├── trim_synchronized_data.m           (Function)
├── analyze_responses.m                (Function)
├── MultiChannelViewer.m               (App Class)
├── pan_tompkin_ecg.m                  (External Function)
├── edf2eeglab.m                       (External EEGLAB Function)
│
├── Markers_EEg_fNIRs.xlsx             (Synchronization Key File)
│
└──   EEG_NIRx_Labchart_Superlab_Data\                     (Data Directory)
        │
        ├── Subject_001\               (Folder name can be anything, e.g., Name/ID)
        │   ├── AFT.mat                (LabChart Data & Markers)
        │   ├── oxyHb.txt              (fNIRS Data)
        │   ├── deoxyHb.txt            (fNIRS Data)
        │   └── EDF.edf                (EEG Data)
        │
        ├── Subject_002\
        │   ├── AFT.mat
        │   ├── ...
        │
        └── ...



3. Files Needed for Each Subject

 These four files must be present in each subject folder with the following precise names:

The MATLAB export from LabChart is called "AFT.mat". Data (ECG), com (numeric markers), comtext (text markers), and samplerate must all be present.

Raw fNIRS oxy-hemoglobin data (columns = channels) is contained in "oxyHb.txt".

raw fNIRS deoxy-hemoglobin data ("deoxyHb.txt").

The raw EEG recording is called "EDF.edf".

4. File Synchronization

EEg_fNIRs.xlsx markers: The translation key is this Excel file. In relation to the LabChart start, it must include the offset timings for the "Start Marker" for fNIRS and EEG. The layout of EEg_fNIRs.xlsx markers is as follows:

Column 1: Subjects (according to the loop order) in rows.

Column 2: offset of the fNIRS start frame.

Column 3: EEG start time offset (mm:ss.sss).

Column 4: Offset of EEG start time (seconds).

4. The Pipeline of Code

A. Matlab_sync_commented.m is the main script.

The master script is this. To begin the analysis, you run this file.

Function: It loops through each subject folder, establishes folders, and initializes the workspace.

Procedure for each subject:

loads unprocessed data (.mat,.txt,.edf files).

synchronizes markers: The Excel key file is used to align fNIRS frames and EEG timepoints to the LabChart markers.

Calls Helper Functions: Performs the following functions described in section 4B one after the other.

Determines Heart Rate: Applys the Pan-Tompkins algorithm to the ECG data that has been clipped.

The interactive App Designer window is opened for manual inspection when the Viewer is launched.

B. Supporting Roles

i. create_derived_channels.m

The goal is to compute bipolar EEG montages (such as "Fp1 - F7") and apply digital filter on the data of EEG and fNIRS, using the function custom_filter.m.

Editing: To alter which electrode pairs are subtracted, make changes to the channel_definitions list contained in this file.

ii. Synchronisation of EEG, fNIRS and ECG (...)

The goal is to slice all four data streams—ECG, EEG, oxyHb, and deoxyHb—to a single time window.

The logic is as follows: it locates the initial and last markers in the synchronized timeline and adds padding (t_before, t_after), which is the length of the record (in seconds) taken before and after the markers, that are specified in the main script.

A. signal_synchroniser.m
Marker Extraction (LabChart): It extracts the marker information from the loaded LabChart data (AFT.mat) as loadedVars. This includes the text of each marker (comtext), the type/sequence of each marker (com_seq), and most importantly, the exact time each marker occurred in the LabChart recording (com_sec_Labchart). It also calculates com_sec_zero, which is the time of each marker relative to the first marker, effectively setting the first event's time to zero.
fNIRS Synchronization: It calculates the marker times in terms of fNIRS data frames. It takes the relative LabChart marker times (com_sec_zero), converts them to frames by multiplying by the fNIRS sampling rate (7.8125 Hz), and then adds the subject-specific frame offset loaded from the Markers_EEG_fNIRs Excel file. This aligns all subsequent markers based on the known position of the first one.
EEG Synchronization: It performs a similar calculation for the EEG data. It takes the relative LabChart marker times (com_sec_zero) and adds the subject-specific time offset (in seconds) from the Markers_EEG_fNIRs Excel file. This gives the precise time of each event within the EEG recording's timeline.
All the extracted and calculated information for the current subject is stored in the struct named compiledData.m.

B. trim_synchronized_data.m 
Adds padding (t_before, t_after), which is the length of the record (in seconds) taken before and after the markers, that are specified in the main script Matlab_sync_commented.m

iii. examine_reactions(compile_reaction_time.m)

Behavioral analysis is the goal.

Output: Provides a struct response_count_prcent_latency.m that include:

ResponseCounts: The number of Correct, Incorrect, and No-Responses for Congruent versus Incongruent images.

ResponsePercentages: Percentages of accuracy.

AverageLatencies: The mean response time for every condition in seconds.

iv. The App, MultiChannelViewer.m

The goal is to visualize all 39 channels (ECG, Hear rate, 21 EEG channels and 16 ECG channels) and markers at once using a graphical user interface.

Characteristics:

Navigation: Use on-screen buttons to move between markers or scroll across epochs.

Markers: Event markers (Correct Response, Incongruent Image, etc.) are shown by vertical green lines.

Heart Rate: Displays the calculated heart rate in a separate subplot. Using pan_tompkin_ecg.m, HR is calculated from ECG.

Epoch duration (in seconds), Y-axis limits (in mV for ECG, in micro volts for EEG, and in mmols for fNIRS), and thresholds (you can display two more lines parallel to the x-axis within Y-axis limits) can all be dynamically changed. In the case of EEG, when the voltage amplitudes of various waves are defined, thresholds might be necessary.

v. How to Conduct the Analysis

Setup Path: Verify that all files are located in the "D:\fNIRS_EEG_project" or folder or in your specified MATLAB Path.

Open matlab_sync_commented.m to edit the main script.

Make sure your data folder is pointed to by updating mainDir (Line 8).

Point to the synchronization key file by updating path of Markers_EEG_fNIRS (Line 30).

In the for n =... loop, update the range to choose which subjects to process.

Run: In MATLAB, click "Run".

Interactive Evaluation:

For the first subject, the Multi-Channel Data Viewer window will appear.

"Load / Apply Settings" will allow you to see the data.

You can examine epochs or markers by using the Navigation buttons (bottom right).

Press 'Q' or select "QUIT APP" to end the window. The script will move on to the next topic on its own.

Results: After the loop is complete, your workspace will have two main variables:

All synchronized raw data and marker timelines are contained in compiledData.m.

Reaction times: Includes each subject's behavioral statistics (accuracy/latency) in response_count_prcent_latency.m.

5.  Additional functions required:

edf2eeglab.m: To read ".edf" files, the edf2eeglab.m function is needed. It is extracted from the libraries of EEGLAB.

References:
1) Pan J, Tompkins WJ. A real-time QRS detection algorithm. IEEE Trans Biomed Eng. 1985 Mar;32(3):230-6
2) Goldberger AL, Amaral LAN, Glass L, Hausdorff JM, Ivanov PC, Mark RG, et al. PhysioBank, PhysioToolkit, and PhysioNet: components of a new research resource for complex physiologic signals. Circulation [Internet]. 2000 Jun 13 [cited 2025 Dec 17];101(23):e215-20. Available from: https://physionet.org/
3) Delorme A, Makeig S. EEGLAB: an open source toolbox for analysis of single-trial EEG dynamics including independent component analysis. J Neurosci Methods. 2004 Mar 15;134(1):9-21.
4) Delorme A. EEGLAB [Software]. Swartz Center for Computational Neuroscience; 2025 [cited 2025 Dec 17]. Available from: https://eeglab.org/

Pan-Tompkins: Verify that the folder containing pan_tompkin_ecg.m is used for HR computation.

Custom filter: To apply custom filter, where we can specify type of filter and cut-off frequencies.

