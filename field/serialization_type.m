classdef serialization_type
    enumeration
        uint8(1, 'uint8')
        uint16(2, 'uint16')
        uint32(4, 'uint32')
        uint64(8, 'uint64')
        int8(1, 'int8')
        int16(2, 'int16')
        int32(4, 'int32')
        int64(8, 'int64')
        single(4, 'single')
        double(8, 'double')
    end
    properties
        length
        str
    end
    methods
        function obj = serialization_type(i, s)
            obj.length = i;
            obj.str = s;
        end
    end
end
