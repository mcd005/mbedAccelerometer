function X25(~)

[mbedpath, port] = initilisation;% function call asks user to input COM port and mbed directory

timeout = 5;                % time to wait for mbed to give data before aborting
T = 1000;                   % sample rate (milliseconds)
d = 0.00277778;             % sample time (hours) duration of data capture from moment 'reset' is pressed
fs = 1000/T;                % sampling frequency
capturedData = zeros(1,2);

exit_flag = 0;                                              % used to quit while loop
while (exit_flag == 0)
    fprintf('\nCapture data by pressing the reset button on the mbed.\nRetrieve this data by selecting option 1 in the menu.\n\n');
    fprintf('1. Retrieve data from mbed\n');
    fprintf('2. Export retrieved data as text file\n');
    fprintf('3. Import saved data from text file\n');
    fprintf('4. Edit the mbed settings file\n');
    fprintf('5. Display time/frequency domain graphs/key data \n');
    fprintf('6. Locate MBED connection settings\n');        % required so that the user can alter serial setting eg. com port
    fprintf('7. Exit program\n');
    
    choice = input('Please select option: ');
    while isempty(choice)                                   % error check: user asked to select an option each time they enter nothing
        choice = input('No input. Please select option: ');
    end
    
    switch choice
        case {1}
            [T, d] = readCaptureSettings(T,d,mbedpath);     % synchronise settings between Matlab and MBED
            n = int16((d*3600)/(T/1000));                   % number of samples when using current sample rate/time paramters
            capturedData = zeros(n+1,2);                    % create empty array of correct size for incomming data
            clear mbed;                                     % prevents premature termination due to existing serial objects
            mbed = serial(port, 'BaudRate',115200, 'Parity','none', 'DataBits',8, 'StopBits',1);% create serial object to represent connection to mbed
            [capturedData] = connectToCapture(mbed, n, capturedData, timeout);
            delete(mbed);                                   % serial object deleted in case connection settings get changed
            
        case {2}
            writeFile(capturedData, T, d);
            
        case {3}
            [capturedData, T, d] = loadFile(capturedData, T, d);
            
        case {4}
            [T, d] = changesystemparams(T, d);              % user specifies settings
            writeCaptureSettings(T,d,mbedpath);             % settings are updated on mbed settings file
            
        case {5}
            if capturedData == 0                            % option 5 is meaningless until option 1 or 3 has been called first
                fprintf('\nPlease capture or load some data first.\n');
                continue;                                   % skips to main menu
            end
            dt = 0:(T/1000):(d*3600);                       % generate x values for graph. Range from 0 to sample time in steps of sample rate
            fs = 1000/T;
            
            fprintf('\n1. Time domain response\n');
            fprintf('2. Key values from time domain\n\n');
            fprintf('3. Frequency domain response (Fast Fourier Transform)\n');
            fprintf('4. Key values from the frequency domain\n');
            
            sub_choice = input('Please select option: ');
            while isempty(sub_choice)                       % see line 23
                sub_choice = input('No input. Please select type of display: ');
            end
            
            switch sub_choice
                case{1}
                    displayTimePlot(capturedData, dt);
                case{2}
                    displayTimedata (capturedData, T, fs);
                case{3}
                    displayFFT(capturedData, T, fs);
                case{4}
                    displayKeyFFT(capturedData, fs);
                otherwise
                    disp('Invalid entry');
            end
            
        case {6}
            [mbedpath, port] = initilisation;
            
        case {7}
            exit_flag = 1;                                  % halts while loop and ends program
            
        otherwise
            disp('Invalid entry');
    end
end
end

function [PathName, port] = initilisation
directory = uigetdir('D:', 'Select MBED directory');    	% store directory to mbed
PathName = strcat(directory, 'SETUP.TXT');                  % string concatenation points directory straight to settings file
port = input('Please enter communication port (eg. com1): ','s');% no validation check here as different operating systems require different inputs
end

function [capturedData] = connectToCapture(mbed, n, capturedData, timeout) %Function: signals to mbed to transfer data into Matlab array over serial
try
    set(mbed,'Timeout',timeout);                            % adjust timeout to ensure fast response when mbed disconnected
    fopen(mbed);                                            % open serial connection
    try
        fprintf(mbed, 'c');                                 % MBED c code is waiting for character 'c' to begin transmitting
    end
    
    i = 1;
    while (i<=n+1)	% loop n+1 times. Sample time=10sec, rate=1sec means n = 10samples but in fact there's 11 data points in order to include t=0 hence +1
        cache = fscanf(mbed, '%f %f\n',[2,1]);              % get values into array assumes data formatted as 'pitch, roll'
        capturedData(i,:) = [cache(1,1) ; cache(2,1)];      % add this iteration of values from cache to data array
        
        i = i+1;                                            % increment index
    end
    
    fclose(mbed);                                           % close serial connection to prevent serial port being locked open
    fprintf('Data successfully captured\n');
    
catch           % error check: in case mbed can't be found or becomes disconnected
    fprintf('Failed\n');
    port = get(mbed,'Port');
    warningMessage = sprintf('Port: %s has been disconnected or is currently busy. Check connection and settings then try again.\n Alternatively (while LED1 flashes) wait until capture is complete.', port);
    uiwait(msgbox(warningMessage));                         % error check: display warning dialogue box
    fclose(mbed);                                           % see line 123
end
end

function writeFile(capturedData, T, d) %Creates new custom named text file storing the capture settings and captured data array permanently
fprintf('\nThe exported text file will be in the same folder as the MATLAB program\n');
filename = input('Enter desired file name: ', 's');

if capturedData == 0                                        % error check: data can't be saved if none currently exists!
    fprintf('\nData not found. Re-capture is reccommended\n');
    return;
end
metadata = [T d];                                           % sample rate and time are placed in a 1x2 array
saveData = cat(1,metadata,capturedData);                    % metadata array added to beginning of captured data array
if exist(filename, 'file')                                  % (Defensive programming) in case file of same name already exits
    warningMessage = sprintf('Warning: file already exists:\n%s', filename);
    uiwait(msgbox(warningMessage));
    fprintf('\nOverwrite file?\n');
    answer = input('Please type y for yes or n for no\n','s');
    if isequal(upper(answer),'Y')                           % (Defensive programming) user could type 'y' or 'Y' as either count as yes
        save(filename,'saveData','-ascii','-double','-tabs');% saves file as a text file on computer
        fprintf('Save successfull\n   ');
    else
        fprintf('No changes made\n   ');
    end
else
    save(filename,'saveData','-ascii','-double','-tabs');   % if file doesn?t already exist saves a new file as a text file on computer
end
end

function [capturedData, T, d] = loadFile(capturedData, T, d) %Loads and organises a previously captured dataset
fprintf('\nEnsure the target file is in the same folder as the MATLAB program\n');
filename = input('Enter the name of the file or type cancel:  ', 's');% get user to enter file name
a = true;
while (a && ~strcmp(filename,'cancel'))                     % if the user were to type 'cancel' this condition wouldn't be met hence function will end
    try
        loadedData = load(filename);                        % error check: this will throw an exception if filename cant be found hence try/catch statements
        metaData = loadedData(1,1:2);                       % first row of array is extracted...
        T = metaData(1,1);                                  % ...and stored in relevant variable
        d = metaData(1,2);
        capturedData = loadedData(2:end,:);                 % the remaining array (row 2 onwards) is kept as 'capturedData'
        if isempty(capturedData)
            error('No data found in file. Check and try again.\n')
        else
        fprintf('Load successfull\n');
        end
        a = false;                                          % exit while loop
        return;
    catch
        fprintf('\nFile not found. Save file in %s and try again.\n', pwd);% directory of program (where file to load should be saved) is highlighted to user
        filename = input('Enter the name of the file or type cancel:  ', 's');
    end
end
end

function [T, d] = readCaptureSettings(T,d,mbedpath) %Check curent mbed data capture configuration
setup = fullfile(mbedpath);                                 % fullfile ensures directory path is technically correct for when later used
try
    fileID = fopen(setup,'r');                              % error check: this will throw an exception if settings file can't be found on MBED hence try/catch statements
    C = textscan(fileID,'%s');                              % the entire settings file is loaded into an array of strings, C
    fclose(fileID);                                         % file is closed for good house keeping
    T = str2num(C{1}{3});                                   % this is the element of C that sample time is stored in and gets stored in T
    d = str2num(C{1}{5});                                   % element of C sample rate is in and gets stored in d
catch           % in case mbed can't be found or becomes disconnected
    warningMessage = sprintf('%s could not be found. Please connect or update path to MBED.\n', mbedpath);
    uiwait(msgbox(warningMessage));
end
end

function [T, d] = changesystemparams(T, d) %Allows the user to choose parameters to update
exit_flag = 0;                                              % used to quit while loop
while (exit_flag == 0)
fprintf('\nChange parameter menu:\n  1. Sample rate\n');
fprintf('  2. Sample time\n');
fprintf('  3. Exit\n');                                     % print menu
choice = input('Please select option to change: ');
    while isempty(choice)                                   % see line 23
        choice = input('No input. Please select option to change: ');
    end
    switch choice
        case{1}
            T = input('Sample rate in milliseconds: ');
            while T < 1                                     % (Defensive programming) Loop enforces user to input sensible values
                T = input('Input must be greater than "1". Enter sample rate in milliseconds: '); % prevents any error when executed by mbed
            end
        case{2}                                             % useful conversion table between hours and seconds is shown
            fprintf('\n  duration  | time (in hours)\n-----------------------------\n  10 seconds|  0.00277778\n   1 minute |  0.01666667\n  30 minutes|  0.50000000\n   1 hour   |  1.00000000\n   1 week   |  168.000000\n   4 weeks  |  672.000000\n   1 year   |  8760.00000\n\n');
            d = input('Sampe time in hours: ');
            if int16((d*3600)/(T/1000)) >= 3500             % error check: prevents a sample number greater than 3000 as this would overflow the MBED memory
                fprintf('Warning: entered parameters may overflow LPC1768 memory. Consider revising.\n');
            end
        case{3}
            exit_flag = 1;
        otherwise
            disp('Invalid entry');
    end
end
end

function writeCaptureSettings(T,D,mbedpath) %Updates the sample time/read values directly on mbed memory
A = regexp( fileread(mbedpath), '\n', 'split');             % each line of settings file is loaded into an array of strings, A
A{2} = sprintf('sample= %i',T);                             % lines 2 and 3 (the elements containing sample time and rate) are re-written with new values
A{3} = sprintf('duration= %f',D);
setup = fopen(mbedpath, 'w');
fprintf(setup, '%s\n', A{:});                               % A (the settings file stored in an array) is loaded back into the file replacing what was there
fclose(setup);                                              % good house keeping
end

function displayTimePlot(capturedData, dt) %Plots time domain data on a graph
figure;                                                     % a new window is created
h(1) = subplot(2,1,1);                                      % allows pitch and roll to be plotted as separate graphs on same figure
plot(dt(1:length(capturedData)),capturedData(:,1),'b');     % plots x data (see line 52) against left hand column of captured data (pitch data)
xlabel('Time [s]');
ylabel('Pitch Angle [°]');
title('Pitch angle in time domain');                        % always label graphs!

h(2) = subplot(2,1,2);                                      % same process for roll data
plot(dt(1:length(capturedData)),capturedData(:,2),'r');
xlabel('Time [s]');
ylabel('Roll Angle [°]');
title('Roll angle in time domain');

linkaxes(h)     % useful engineering refinement that allows each side by side graph to be visually comparable with the same scale
end

function displayFFT(capturedData, T, fs) %Plots frequency domain data on a graph
s = length(capturedData);                                   % length of signal (fft size)
nfft = 2^nextpow2(s);                                       % find new input length that is next power of 2 from s to improve fft performance
y_pitch = fft(capturedData(:,1),nfft)/s;                    % convert to frequency domain
y_roll = fft(capturedData(:,2),nfft)/s;
f = fs/2 * linspace(0,1,nfft/2+1);                          % frequency axis vector
power_ypitch = abs(y_pitch);
power_yroll = abs(y_roll);

fprintf('\nDisplay pitch and roll on single graph?\n');     % because real oscillations are likely to occur in both pitch and roll axis together there's
                                                         	% little distinguishing them so it's logical to plot both waveforms on a single graph
answer = input('Please type y for yes or n for no\n','s');
figure;
if isequal(upper(answer),'Y')
    plot(f,power_ypitch(1:nfft/2+1),'b'); hold on;          % plot frequency domain waveform
    plot(f,power_yroll(1:nfft/2+1),'r')
    ylabel('Magnitude');
    xlabel('Frequency [Hz]');
    title('Pitch and roll angle (blue and red) in frequency domain');
    
else
    h(1) = subplot(2,1,1);
    plot(f,power_ypitch(1:nfft/2+1),'b');
    ylabel('Magnitude');
    xlabel('Frequency [Hz]');
    title('Pitch angle in frequency domain');
    
    h(2) = subplot(2,1,2);
    plot(f,power_yroll(1:nfft/2+1),'r')
    ylabel('Magnitude');
    xlabel('Frequency [Hz]');
    title('Roll angle in frequency domain');
    
    linkaxes(h)                                             % see line 239
end
end

function displayTimedata (capturedData, T, fs) %Written by: Tom. Function: gives user values of relevant data in respect to the time domain.

[pks, locs] = findpeaks(capturedData(:,1),fs,'Npeaks',1,'sortstr','descend');
fprintf('The greatest pitch angle is %f° and is at %f seconds\n',pks,locs);
[pks, locs] = findpeaks(-capturedData(:,1),fs,'Npeaks',1,'sortstr','descend');
fprintf('The lowest pitch angle is %f° and is at %f seconds\n',-pks,locs);
y = peak2peak(capturedData(:,1));
fprintf(' %f max peak to peak pitch\n',y);

[pks, locs] = findpeaks(capturedData(:,2),fs,'Npeaks',1,'sortstr','descend');
fprintf('The greatest roll angle is %f° and is at %f seconds\n',pks,locs);
[pks, locs] = findpeaks(-capturedData(:,2),fs,'Npeaks',1,'sortstr','descend');
fprintf('The lowest roll angle is %f° and is at %f seconds\n',-pks,locs);
y = peak2peak(capturedData(:,2));
fprintf(' %f max peak to peak roll\n',y);

end

function displayKeyFFT(capturedData,fs) %Written by: Jamie.
%This code takes the pitch and roll data and passes it through the
%MATLAB FFT function. See displayFFT for details.

m = length(capturedData);
nfft = 2^nextpow2(m);
y_pitch = fft(capturedData(:,1),nfft)/m;
y_roll = fft(capturedData(:,2),nfft)/m;
f = fs * linspace(0,1,nfft);
power_ypitch = abs(y_pitch);
power_yroll = abs(y_roll);

%I used the findpeaks function in MATLAB to sort for the maximum values of
%magnitude from the FFT and print out those values and the frequency's they
%occur. This is done for both pitch and roll.
[pmax, pmax_loc] = findpeaks(power_ypitch,f,'Npeaks',1,'sortstr','descend');
fprintf('\nThe highest peak for pitch is %f and is at %f Hz\n',pmax,pmax_loc);

[rmax, rmax_loc] = findpeaks(power_yroll,f,'Npeaks',1,'sortstr','descend');
fprintf('The highest peak for roll is %f and is at %f Hz\n',rmax,rmax_loc);
end