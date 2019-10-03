% function batch(numFilesPerBatch, idxFirstFile)

%
%% Setup
setup_workspace; % sets up paths, clears workspace and command window

[Options, Display] = load_default_options_display;
ChannelCombiner = load_default_channel_combiner(Display);

% this causes matlab to close on error, used for batch mode processing
Options.batch_mode = false;

Display.figure_format='-dpng';
% directory to save figure to, created if doesn't exist
Display.figure_path = pwd;
%

uniqueIds = fopen("./allUniqueIds.txt");
numFilesPerId = fopen("./numFilesPerId.txt");
preChannelName = "Channel";
numChannel = 4;
numFilesPerBatch = 3;
idxFirstFile = 3;
nameBatchRes = cell(16, numChannel);
% channelIdx = 1;
while ~feof(uniqueIds)

    Id = fgetl(uniqueIds);
    lenId = length(Id);
    numFilesStr = fgetl(numFilesPerId);
    numFiles = str2num(numFilesStr);

    if((Id(lenId-7:lenId-1) == "Channel") || (Id(lenId-2:lenId-1) == "Ch"))
        sprintf("Valid name format");
    else
        sprintf("Invalid name format. The name of .mat files should be *Channel*");
        continue;
    end    

    for i = lenId:-1:1
        if(Id(i) == '/')
            dataDir = Id(1:i);
            channelName = Id(i+1:lenId-1);
            fileName = Id(i+1:lenId);
            break;
        end
    end

    idxFileStr = numbertostring(idxFirstFile);
    file0 = [fileName, '_', idxFirstFile, '.mat'];
    %
    %% Configure override settings
    % this is for loading a single file to setup for the simulated batch due to
    % parfor loops requiring everything to be preallocated
    DataLoaderOver.signal_type = 'vhf';
    DataLoaderOver.config_dir = dataDir;
    DataLoaderOver.data_dir = dataDir;
    DataLoaderOver.gps_dir = dataDir;
    DataLoaderOver.file0 = file0;
    DataLoaderOver.num_files = numFilesPerBatch;
    
    if (preChannelName ~= channelName)
        % need to generate a system structure to create an array for the parfor
        [Constants, DataLoader] = load_prelim_params('DataLoader', ...
            DataLoaderOver);
        SystemOverride = configure_system(DataLoader, Constants);
        SystemLocal = repmat(SystemOverride, 16, numChannel);
        clear systemOverride;
        %

        % channelIdx = str2num(Id(lenId)) + 1;
        channelIdx = 1;
    else
        channelIdx = channelIdx + 1;
    end

    if(numFiles < numFilesPerBatch)
        numFilesCurBatch = numFiles;
        idxFileStr = numbertostring(idxFirstFile);
        file0 = [fileName, '_', idxFirstFile, '.mat'];
        numBatch = 1;

        %
        %% Configure override settings
        % this is for loading a single file to setup for the simulated batch due to
        % parfor loops requiring everything to be preallocated
        DataLoaderOver.signal_type = 'vhf';
        DataLoaderOver.config_dir = dataDir;
        DataLoaderOver.data_dir = dataDir;
        DataLoaderOver.gps_dir = dataDir;
        DataLoaderOver.file0 = file0;
        DataLoaderOver.num_files = numFilesCurBatch;

        %% First main script
        % need to keep the System structure from one of the batch jobs. NOTE:
        % all files within one time stamp should have same configuration. Also
        % need to save the paths for inputting to the combine_channel function.
        [~, SystemLocal(1, channelIdx), nameBatchRes{1, channelIdx}] = ...
            channel_processor(Options, Display, ...
            'DataLoader', DataLoaderOver);
        fprintf('\n\n\n');
        %

    else
        numFilesRe = mod(numFiles, numFilesPerBatch);
        if (numFilesRe < 50)
            numBatch = (numFiles - numFilesRe) / numFilesPerBatch;
        else 
            numBatch = (numFiles - numFilesRe) / numFilesPerBatch + 1;
        end

        for j = 1:numBatch
            if (j == numBatch)
                idxFile = (j-1) * numFilesPerBatch + 3;
                numFilesCurBatch = numFiles - idxFile + idxFirstFile;
                idxFileStr = numbertostring(idxFile);
                file0 = [fileName, '_', idxFileStr, '.mat'];

                %
                %% Configure override settings
                % this is for loading a single file to setup for the simulated batch due to
                % parfor loops requiring everything to be preallocated
                DataLoaderOver.signal_type = 'vhf';
                DataLoaderOver.config_dir = dataDir;
                DataLoaderOver.data_dir = dataDir;
                DataLoaderOver.gps_dir = dataDir;
                DataLoaderOver.file0 = file0;
                DataLoaderOver.num_files = numFilesCurBatch;

                %% First main script
                % need to keep the System structure from one of the batch jobs. NOTE:
                % all files within one time stamp should have same configuration. Also
                % need to save the paths for inputting to the combine_channel function.
                [~, SystemLocal(j, channelIdx), nameBatchRes{j, channelIdx}] = ...
                    channel_processor(Options, Display, ...
                    'DataLoader', DataLoaderOver);
                fprintf('\n\n\n');
                %

            else
                numFilesCurBatch = numFilesPerBatch;
                idxFile = (j-1) * numFilesPerBatch + idxFirstFile;
                idxFileStr = numbertostring(idxFile);
                file0 = [fileName, '_', idxFileStr, '.mat'];

                %
                %% Configure override settings
                % this is for loading a single file to setup for the simulated batch due to
                % parfor loops requiring everything to be preallocated
                DataLoaderOver.signal_type = 'vhf';
                DataLoaderOver.config_dir = dataDir;
                DataLoaderOver.data_dir = dataDir;
                DataLoaderOver.gps_dir = dataDir;
                DataLoaderOver.file0 = file0;
                DataLoaderOver.num_files = numFilesCurBatch;

                %% First main script
                % need to keep the System structure from one of the batch jobs. NOTE:
                % all files within one time stamp should have same configuration. Also
                % need to save the paths for inputting to the combine_channel function.
                [~, SystemLocal(j, channelIdx), nameBatchRes{j, channelIdx}] = ...
                    channel_processor(Options, Display, ...
                    'DataLoader', DataLoaderOver);
                fprintf('\n\n\n');
                %
            end
        end
    end

    if (channelIdx == numChannel)
        % these need to be loaded here. might make a script for this later
        ChannelCombiner.input_files = cell(1, channelIdx);
        ChannelCombiner.reference_channel_num = str2num(Id(lenId));

        for n = 1:numBatch
            for k = 1:channelIdx
                local_input_files{1,k} = nameBatchRes{n, k};
            end

            %
            %% Second main script
            % Set the files to be used for the channel combining. May need to add a
            % loop here if processing more than one block of channels. ie all
            % channels with file 0001_0100_cpr and file 0101_0200_cpr would require a
            % loop to do file 0001_0100_cpr and file 0101_0200_cpr seperately
            ChannelCombiner.input_files = local_input_files;
            System = SystemLocal(1,k);

            ImageProcessor.input_files{n} = combine_channels(Options, Display, ...
                ChannelCombiner);
            fprintf('\n\n\n');
        end

        %% Third main script
        % This assumes ImageProcessor has a list of all the combined data to be
        % used
        image_processor(Options, Display, ImageProcessor, 'System', System, ...
            'DataLoader', DataLoaderOver);
        %
    end

    preChannelName = channelName;

end

% end

function numtostr = numbertostring(decNum)
    if decNum < 10
        numtostr = ['000' num2str(decNum)];
    elseif decNum>=10 && decNum<=99
        numtostr = ['00' num2str(decNum)];
    elseif decNum>=100 && decNum<=999
        numtostr = ['0' num2str(decNum)];
    else
        numtostr = [num2str(decNum)];
    end
end
