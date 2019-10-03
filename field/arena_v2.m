function [trace_time, Results] = arena_v2 (xml_fullpath, dat_fullpath)

if ~isfile(xml_fullpath)
    fprintf('ERROR: XML config file %s does not exist.\n', xml_fullpath);
    exit;
end

if ~isfile(dat_fullpath)
    fprintf('ERROR: dat file %s does not exist.\n', dat_fullpath);
    exit;
end

%% Code last updated by Zhe Jiang on April 12
fprintf(strcat('starting ',dat_fullpath, '......\n'));

debug_mode = 0;
unsync_patience = 10000000;


%% Preparation Phase
% Parse XML file and determine selected range gate to avoid issues with
% ARENA software bug.
[my_modes,my_range_gates,socket_payload_size] = arena_xml_parse_v2(xml_fullpath);

if isempty(my_modes)
fprintf('Failed to parse modes from xml config file %s. Exiting. \n',xml_fullpath);
exit;
end

% Define a variable for all results
Results = struct('Mode',{}, 'Chirps',{}, 'Relative_Counters',{}, ...
    'Profile_Counters',{}, 'PPS_Fractional_Counters',{}, ...
    'PPS_Time',{},'PPS_Counters',{}, 'counter',{});
for i = 1:size(my_modes,2)
    Results(i).Mode = my_modes(1,i);
    Results(i).counter = 0;
end

% Set up constant parameters.
data_block_size = socket_payload_size + 32;
sync_word = [0;0;0;128;0;0;128;127];

sync_word = 9187343241983295488;

% Find all *.dat files and *_config.xml files.
dat_file = dir(dat_fullpath);
%radar_data = [];
%pps_time = [];
rel_time_min = Inf;
rel_time_max = -Inf;

%% Extracting UDP packets and save to a temporary file
% Open radar.dat temporary file.
%tmp_fullpath = strcat(dat_fullpath(1:(end-3)),'tmp');
[tmp_filepath,tmp_name,tmp_ext] = fileparts(dat_fullpath);
tmp_dir = '/scratch/';
tmp_fullpath = strcat(tmp_dir,tmp_name, '.tmp');

% Reading the .dat file
%   tic
% Open *.dat file.
file_id = fopen(dat_fullpath, 'r');
if file_id == -1
        fprintf('ERROR: could not open %s. Exiting.', dat_fullpath); return;
else
    %fprintf('%s opened for processing.\n', dat_fullpath);
payload_stream = byte_stream(fread(file_id, dat_file.bytes, 'uint8=>uint8'));

% Close *.dat file.
if fclose(file_id) == 0
    %fprintf('%s closed.\n', dat_fullpath);
else
    fprintf('ERROR: %s could not be closed. Exiting.', ...
        dat_fullpath);return;
end


% Calculate the number of data blocks in the *.dat file.
num_data_blocks = dat_file.bytes / data_block_size;

  % instead of reading and writing uint8 (default) we go for writing uint64
  % this significantly speed up the routine
  % No speed up is found when defining a structure beforehand
  % and writing this to disk as one big chunk instead stepwise small of chunks

% preallocate array to avoid O(n^2) time to build array
binary_array = zeros(num_data_blocks * socket_payload_size, 1, 'uint8');

%     % Assemble radar payloads from this *.dat file.
for j = 1:num_data_blocks
    daq_packet_time_stamp_s = double(payload_stream.read(1, serialization_type.uint32));
    daq_packet_time_stamp_us = double(payload_stream.read(1, serialization_type.uint32));

    % variables are unused, so we can fseek forward
    payload_stream.seek(32 - 8, 'cof');
    %arena_payload_type = payload_stream.read(1, serialization_type.uint32);
    %arena_payload_length = payload_stream.read(1, serialization_type.uint32);
    %arena_id = payload_stream.read(1, serialization_type.uint16);
    %mezzanine_id = payload_stream.read(1, serialization_type.uint16);
    %packet_time_s = payload_stream.read(1, serialization_type.uint32);
    %packet_time_us = payload_stream.read(1, serialization_type.uint32);
    %packet_counter = payload_stream.read(1, serialization_type.uint32);

    rel_time_raw = daq_packet_time_stamp_s + daq_packet_time_stamp_us*10d-7;
    rel_time_min = min(rel_time_min, rel_time_raw);
    rel_time_max = max(rel_time_max, rel_time_raw);
%      radar_payload = fread(file_id, socket_payload_size,'uint8');
%      fwrite(radar_id, radar_payload);

% speed up 
% please not: there is a mismatch for large uint64 number when using
% typecast on uint8 and reading uint64
% the later would be faster however the exact data is not reproduced
% therefore we stick to reading unint8 data
%        radar_payload = typecast(uint64(fread(file_id, socket_payload_size/8,'uint64')),'uint64');

    radar_payload = payload_stream.read(socket_payload_size, serialization_type.uint8);
    binary_array((j - 1) * socket_payload_size + 1:j * socket_payload_size) = radar_payload;
end

rel_time_min = double(rel_time_min);
rel_time_max = double(rel_time_max);

%fprintf('\n%d UDP packets processed.\n', num_data_blocks);

end
%toc
   
    
    clear payload_stream file_id num_data_blocks j daq_packet_time_stamp_s ...
    daq_packet_time_stamp_us arena_payload_type arena_payload_length ...
    arena_id mezzanine_id packet_time_s packet_time_us packet_counter ...
    radar_payload;

%fprintf('Radar payload extracted from all *.dat files.\n');


%% Parsing the temporary file to extract chirps and variables
%% Phase 1: counter the number of chirps in each mode to preallocate memory
% Unpack radar payload from temporary file.
% Open radar.dat file.
radar_id = byte_stream(binary_array);
% Cycle through all the radar payload packets.
%fprintf('Extracting raw data. This may take a while.\n');
%tic
counter = 0;
start_pointer = 0;
unsync_times = 0;
while true
    % Read in sync word and error check.
%    sync = radar_id.read(8);
    sync = radar_id.read(1,serialization_type.uint64);
    if radar_id.eof()
        break;
    end
    if ~isequal(sync,sync_word)
unsync_times=unsync_times+1;
if mod(unsync_times,unsync_patience)==0
fprintf('unsync %d times now! Give up corrupted file\n',unsync_times);return;
end
        % check the whole file for the first sync
        status = radar_id.seek(-7,'cof');
        if status == -1
          fprintf('Failed to move back file pointer for resync. Exiting.'); return;
        end
continue;
    end


    % Read in radar header type and length together.
    %radar_header_type = radar_id.read(8, serialization_type.uint8);
    radar_id.seek(8, 'cof');
    if radar_id.eof()
        break;
    end
    
    % Read in mode;
    mode = radar_id.read(1, serialization_type.uint8);
    mode_index = find(my_modes==mode);
    if radar_id.eof()
        break;
    end
    
    % Trash all remaining profile header data
    % dummy_bytes = radar_id.read(48-1, serialization_type.uint8);
    radar_id.seek(48-1, 'cof');
    if radar_id.eof()
        break;
    end

    % Read in radar profile data format.
    radar_profile_data_format = radar_id.read(4, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    
    % Read in radar profile length.
    radar_profile_length = radar_id.read(1, serialization_type.uint32);
    if radar_id.eof()
        break;
    end
    
    % Calculate actual radar profile length in bytes to account for ARENA 
    % software bug.
    num_samples_per_profile = my_range_gates(2,mode_index)-my_range_gates(1,mode_index)+1;

    % Read in radar profile data.
    %clear i;
    bounced = 0;
    radar_data_raw = [];

    
    if isequal(radar_profile_data_format, [0;0;0;0])
        sample_size = 2;
        radar_data_raw = radar_id.read(num_samples_per_profile, serialization_type.int16);
    elseif isequal(radar_profile_data_format, [0;0;1;0])
        sample_size = 2;
        radar_data_raw = radar_id.read(num_samples_per_profile, serialization_type.uint16);
    elseif isequal(radar_profile_data_format, [0;0;2;0])
        sample_size = 8;
        
        % slight speed up when reading int64 in combination with typecast instead reading int32
        % new_trace = radar_id.read(2*num_samples_per_profile, 'int32');
profile_bytes =radar_id.read(num_samples_per_profile, serialization_type.int64);
    
    if radar_id.eof()
        break;
    end
        new_trace = (typecast(int64(profile_bytes), 'int32'));
    
        radar_data_raw=complex(new_trace(1:2:end,:),new_trace(2:2:end,:));
    elseif isequal(radar_profile_data_format, [0;0;3;0])
        sample_size = 8;
        new_trace = radar_id.read(2*num_samples_per_profile, serialization_type.double);
    if radar_id.eof()
        break;
    end
        radar_data_raw=complex(new_trace(1:2:end,:),new_trace(2:2:end,:));
    else
        fprintf('ERROR: unknown radar profile data format in %s. Exiting.',dat_fullpath); return; %continue;
    end
    
        if radar_id.eof()
             bounced = 1;
             break;
         end

    %pps_time_raw = pps_counter + pps_fractional_counter*10d-8;
    %pps_time = [pps_time pps_time_raw];

   counter = counter +1;

   Results(mode_index).counter = Results(mode_index).counter + 1;

     if bounced
         break;
     end
 %     
    % Store all necessary information (currently only storing the profile
    % data).
    %radar_data = [radar_data radar_data_raw];
end
%toc



% Pre allocate array for Chirps
for j = 1:size(my_modes,2)
    tmp = zeros(my_range_gates(2,j)-my_range_gates(1,j)+1, Results(j).counter);
    Results(j).Chirps = complex(tmp,0);
    Results(j).Relative_Counters = zeros(1, Results(j).counter);
    Results(j).Profile_Counters = zeros(1, Results(j).counter);
    Results(j).PPS_Fractional_Counters = zeros(1, Results(j).counter);
    Results(j).PPS_Time = zeros(1, Results(j).counter);
    Results(j).PPS_Counters = zeros(1, Results(j).counter);
    
    %now all result memory are allocated
    %we can clean up counters to use incremental counter for assigning chirp to the right column
    Results(j).counter = 0; 
end


%% Parsing the temporary file to extract chirps and variables
%% Phase 2: read profile chirps to assign chirp to the right memory column

radar_id.rewind();
counter = 0;
start_pointer =0;
unsync_times=0;
%tic
while true
    % Read in sync word and error check.
%    sync = radar_id.read(8);
    sync = radar_id.read(1,serialization_type.uint64);
    if radar_id.eof()
        break;
    end
    if ~isequal(sync,sync_word)
unsync_times=unsync_times+1;
if mod(unsync_times,unsync_patience)==0
return;
end
%fprintf('unsync %d times now!\n',unsync_times);
        % check the whole file for the first sync
        status = radar_id.seek(-7,'cof');
        if status == -1
          fprintf('Failed to resync file pointer. Exiting.'); return;
        end
continue;
    end


    % Read in radar header type.
    radar_header_type = radar_id.read(4, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    
    % Read in radar header length.
    radar_header_length = radar_id.read(4, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    
    % Read in mode;
    mode = radar_id.read(1, serialization_type.uint8);
    mode_index = find(my_modes==mode);
    % Increase counter for mode, but be careful for last incomplete chirp!
    Results(mode_index).counter = Results(mode_index).counter +1;

    if radar_id.eof()
        break;
    end
    
    % Read in subchannel and data source.
    new_byte = radar_id.read(1, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    subchannel = mod(new_byte, 16);
    data_source = floor(new_byte / 16);
    
    % Trash reserved section.
    reserved_6 = radar_id.read(6, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    
    % Read in encoder.
    encoder = radar_id.read(4, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    
    % Trash reserved section.
    reserved_4 = radar_id.read(4, serialization_type.uint8);
    if radar_id.eof()
        break;
    end
    
    % Read in relative counter.
    relative_counter = radar_id.read(1,serialization_type.uint64);
    if radar_id.eof()
 Results(mode_index).counter = Results(mode_index).counter - 1;
    break;
    end
    
    % Read in profile counter;
    profile_counter = radar_id.read(1,serialization_type.uint64);
    if radar_id.eof()
 Results(mode_index).counter = Results(mode_index).counter - 1;
    break;
    end
    
    % Read in pps fractional counter.
    % casted to double to emulate original behavior
    pps_fractional_counter = double(radar_id.read(1,serialization_type.uint64));
    if radar_id.eof()
 Results(mode_index).counter = Results(mode_index).counter - 1;
    break;
    end
    
    % cast to double to emulate original script
    % Read in pps counter.
    pps_counter = double(radar_id.read(1,serialization_type.uint64));
    if radar_id.eof()
 Results(mode_index).counter = Results(mode_index).counter - 1;
    break;
    end

    
    % Read in radar profile data format.
    radar_profile_data_format = radar_id.read(4, serialization_type.uint8);
    if radar_id.eof()
Results(mode_index).counter = Results(mode_index).counter - 1;
        break;
    end
    
    % Read in radar profile length.
    radar_profile_length = radar_id.read(1,serialization_type.uint32);
    if radar_id.eof()
Results(mode_index).counter = Results(mode_index).counter - 1;
        break;
    end
    
    % Calculate actual radar profile length in bytes to account for ARENA 
    % software bug.
    num_samples_per_profile = my_range_gates(2,mode_index)-my_range_gates(1,mode_index)+1;

    % Read in radar profile data.
    %clear i;
    bounced = 0;
    radar_data_raw = [];

    
    if isequal(radar_profile_data_format, [0;0;0;0])
        sample_size = 2;
        radar_data_raw = radar_id.read(num_samples_per_profile, serialization_type.int16);
    elseif isequal(radar_profile_data_format, [0;0;1;0])
        sample_size = 2;
        radar_data_raw = radar_id.read(num_samples_per_profile, serialization_type.uint16);
    elseif isequal(radar_profile_data_format, [0;0;2;0])
        sample_size = 8;
        
        % slight speed up when reading int64 in combination with typecast instead reading int32
 %       new_trace = radar_id.read(2*num_samples_per_profile, 'int32');
profile_bytes =radar_id.read(num_samples_per_profile, serialization_type.int64);
     if radar_id.eof()
 Results(mode_index).counter = Results(mode_index).counter - 1;
    break;
    end
        
new_trace = (typecast(int64(profile_bytes), 'int32'));
        
        radar_data_raw=complex(new_trace(1:2:end,:),new_trace(2:2:end,:));
    elseif isequal(radar_profile_data_format, [0;0;3;0])
        sample_size = 8;
        new_trace = radar_id.read(2*num_samples_per_profile, serialization_type.double);
     if radar_id.eof()
 Results(mode_index).counter = Results(mode_index).counter - 1;
    break;
    end

            radar_data_raw=complex(new_trace(1:2:end,:),new_trace(2:2:end,:));
    else
        fprintf('ERROR: unknown radar profile data format in %s. Exiting.',dat_fullpath); 
return;
%Results(mode_index).counter = Results(mode_index).counter - 1;
%continue;
    end
    
        if radar_id.eof()
             Results(mode_index).counter = Results(mode_index).counter - 1;
             bounced = 1;
             break;
         end

    pps_time_raw = pps_counter + pps_fractional_counter*10d-8;
    %pps_time = [pps_time pps_time_raw];
    Results(mode_index).PPS_Time(1,Results(mode_index).counter) = pps_time_raw;
    Results(mode_index).Relative_Counters(1, Results(mode_index).counter) = relative_counter;
    Results(mode_index).Profile_Counters(1, Results(mode_index).counter) = profile_counter;
    Results(mode_index).PPS_Fractional_Counters(1,Results(mode_index).counter) = pps_fractional_counter;
    Results(mode_index).PPS_Counters(1,Results(mode_index).counter) = pps_counter;
    
    col_id = Results(mode_index).counter;
    Results(mode_index).Chirps(:,col_id) = radar_data_raw;
    


    counter = counter +1;
     if bounced
         break;
     end
%     
    % Store all necessary information (currently only storing the profile
    % data).
    
    %radar_data = [radar_data radar_data_raw];
    
    
end
%toc


%% Remaining Cleanups

clear sync sync_word radar_header_type radar_header_length mode ...
    new_byte subchannel data_source reserved_6 encoder reserved_4 ...
    relative_counter profile_counter pps_fractional_counter pps_counter ...
    radar_profile_length sample_size num_samples_per_profile ...
    radar_profile_data;
% Print out data format message.
clear radar_profile_data_format;



% now interpolate the rel_time to a time for each trace as we observed some
% time steps in the pps_time
 trace_time = (1:counter) * (rel_time_max - rel_time_min) / (counter-1) + rel_time_min;

% Delete radar.dat file.
clear radar_id;
mat_fullpath = strcat(dat_fullpath(1:(end-3)),'mat');
mat_counter_fullpath = strcat(dat_fullpath(1:(end-4)),'_counters.mat');
Counters = Results;
for i = 1:size(my_modes,2)
    Counters(i).Chirps = [];
end
 
save(mat_fullpath, 'Results','trace_time','-v7');
fprintf(strcat('finishing ',mat_fullpath, '......\n'));
save(mat_counter_fullpath, 'Counters','trace_time','-v7');
fprintf(strcat('finishing ',mat_counter_fullpath, '......\n'));
%toc
