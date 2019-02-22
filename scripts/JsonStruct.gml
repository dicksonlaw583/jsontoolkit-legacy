///JsonStruct(source)
// JsonStruct("filename"): Load JSON data from file
if (is_string(argument0)) {
    var f = file_text_open_read(argument0),
        jsonstr = "";
    while (!file_text_eof(f)) {
        jsonstr += file_text_read_string(f);
        file_text_readln(f);
    }
    file_text_close(f);
    return json_decode(jsonstr);
}
// JsonStruct(constructor): Return the data part of the given constructor helper
else if (is_array(argument0)) {
    switch (argument0[1]) {
        case ds_type_map: return argument0[0];
        case ds_type_list:
            var m = ds_map_create();
            ds_map_add_list(m, "default", argument0[0]);
            return m;
        default:
            show_error("Invalid source constructor.", true);
    }
}
// Unrecognized
else {
    show_error("Invalid source type.", true);
}

