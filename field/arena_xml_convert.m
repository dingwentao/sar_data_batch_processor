function arena_xml_convert(xml_fullpath)
    dest_path = strcat(xml_fullpath, '.tmp.mat');
    [my_modes,my_range_gates,socket_payload_size] = arena_xml_parse(xml_fullpath); 
    save(dest_path, 'my_modes', 'my_range_gates', 'socket_payload_size');
end
