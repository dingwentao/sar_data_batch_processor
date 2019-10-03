classdef byte_stream < handle
    properties (Access = private)
        position
        array
    end
    methods
        % constructor (receives column vector)
        function obj = byte_stream(array)
            obj.array = array;
            % position == size(obj.array, 1) + 1 means that eof has been reached
            obj.position = 0;
        end
        % reads elements (integer) where the type of element is determined by type, and advances the position
        % e.g. str.read(3, 'uint64') returns an array of three uint64s and advances the position by 24 bytes
        function r = read(obj, elements, type)
            % look up sizes and type conversions for type string

            % check for negative index
            if elements < 0
                error('Error in byte_stream.read. \ninvalid number of elements');
            end

            length = type.length;

            % detect reading past the end
            if obj.position + elements * length > size(obj.array, 1)
                remaining = floor((size(obj.array, 1) - obj.position) / length);
                r = typecast(obj.array(1 + obj.position:obj.position + remaining * length), type.str);
                obj.position = size(obj.array, 1) + 1;
                return;
            end

            distance = elements * length;
            r = obj.array(1 + obj.position:obj.position + distance);
            r = typecast(r, type.str);
            obj.position = obj.position + distance;
        end
        % check if the end of the stream has been reached
        function r = eof(obj)
            r = obj.position > size(obj.array, 1);
        end
        function r = seek(obj, offset, origin)
            base = 0;

            if origin == 'bof'| origin == -1
                base = 0;
            elseif origin == 'cof' | origin == 0
                base = obj.position;
            elseif origin == 'eof' | origin == 1
                base = size(obj.array, 1);
            else
                error('Error in byte_stream.seek. \ninvalid origin');
            end

            location = base + offset;

            if location < 0 | location > size(obj.array, 1)
                r = -1;
                return;
            end

            obj.position = location;
            r = 0;
        end
        function r = tell(obj)
            r = min(obj.position, size(obj.array, 1));
        end
        % move position back to start of stream
        function r = rewind(obj)
            obj.position = 0;
        end
        function delete(obj)
            clear obj.array;
        end
    end
end
