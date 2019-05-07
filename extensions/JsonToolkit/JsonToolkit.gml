#define JsonStruct
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


#define JsonList
///JsonList(...)
var tuple, list, value;
list = ds_list_create();
tuple[1] = ds_type_list;
tuple[0] = list;
for (var i = 0; i < argument_count; i++) {
    value = argument[i];
    if (is_array(value)) {
        switch (value[1]) {
            case ds_type_map:
                ds_list_add(list, value[0]);
                ds_list_mark_as_map(list, i);
                break;
            case ds_type_list:
                ds_list_add(list, value[0]);
                ds_list_mark_as_list(list, i);
                break;
            default:
                show_error("Invalid value " + string(i) + " for JSON list constructor.", true);
        }
    } else {
        ds_list_add(list, value);
    }
}
return tuple;


#define JsonMap
///JsonMap(...)
if (argument_count mod 2 != 0) {
    show_error("Expected an even number of arguments, got " + string(argument_count) + ".", true);
}
var tuple, map, key, value;
map = ds_map_create();
tuple[1] = ds_type_map;
tuple[0] = map;
for (var i = 0; i < argument_count; i += 2) {
    key = argument[i];
    value = argument[i+1];
    if (is_array(value)) {
        switch (value[1]) {
            case ds_type_map:
                ds_map_add_map(map, key, value[0]);
                break;
            case ds_type_list:
                ds_map_add_list(map, key, value[0]);
                break;
            default:
                show_error("Invalid value pair " + string(i >> 1) + " for JSON map constructor.", true);
        }
    } else {
        ds_map_add(map, key, value);
    }
}
return tuple;


#define json_exists
///json_exists(jsonstruct, ...)
if (argument_count == 0) {
    show_error("Expected at least 1 argument, got " + string(argument_count) + ".", true);
}
// Build the seek path
var path = array_create(argument_count),
    pc = 1;
for (var i = 1; i < argument_count; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[pc++] = argi[j];
        }
    } else {
        path[pc++] = argi;
    }
}
// Return the path validity marker from _json_dig
_json_dig(argument[0], path, 0);
return path[0];


#define json_encode_as_list
///json_encode_as_list(jsonstruct)
// Encode first
var jsonstr = json_encode(argument0);
// Find opening [
var opening_pos = string_pos("[", jsonstr);
// Find closing ]
for (var closing_pos = string_length(jsonstr); closing_pos > opening_pos; closing_pos--) {
    if (string_char_at(jsonstr, closing_pos) == "]") break;
}
// Return trimmed encode if valid
if (opening_pos >= 12 && opening_pos < closing_pos) {
    return string_copy(jsonstr, opening_pos, closing_pos-opening_pos+1);
}
return "";


#define json_get
///json_get(jsonconstruct, ...)
if (argument_count == 0) {
    show_error("Expected at least 1 argument, got " + string(argument_count) + ".", true);
}
// Build the seek path
var path = array_create(argument_count),
    pc = 1;
for (var i = 1; i < argument_count; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[pc++] = argi[j];
        }
    } else {
        path[pc++] = argi;
    }
}
// Return the result of _json_dig
return _json_dig(argument[0], path, 0);


#define json_set
///json_set(@jsonstruct, ..., value)
if (argument_count < 3) {
    show_error("Expected at least 3 arguments, got " + string(argument_count) + ".", true);
}

// Build the seek path
var path = array_create(argument_count-1),
    pc = 0;
for (var i = 1; i < argument_count-1; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[++pc] = argi[j];
        }
    } else {
        path[++pc] = argi;
    }
}
// Special: Dig at least to default if only path value is real
var single_real_path = pc == 1 && is_real(path[1]);
if (single_real_path) {
    path[2] = path[1];
    path[1] = "default";
    pc = 2;
}

// Stop if _json_dig() errors out
var current = _json_dig(argument[0], path, 1);
if (path[0] <= 0) {
    return path[0];
}

// Attempt to set the target
var k = path[pc];
if (is_string(k) && !_json_not_ds(current, ds_type_map)) {
    current[? k] = argument[argument_count-1];
} else if (is_real(k) && !_json_not_ds(current, ds_type_list)) {
    current[| k] = argument[argument_count-1];
} else {
    if (single_real_path) {
        return -1;
    }
    return -pc;
}

// Success!
return 1;


#define json_set_nested
///json_set_nested(@jsonstruct, ..., jsonsubdata)
if (argument_count < 3) {
    show_error("Expected at least 3 arguments, got " + string(argument_count) + ".", true);
}

// Build the seek path
var path = array_create(argument_count-1),
    pc = 0;
for (var i = 1; i < argument_count-1; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[++pc] = argi[j];
        }
    } else {
        path[++pc] = argi;
    }
}
// Special: Dig at least to default if only path value is real
var single_real_path = pc == 1 && is_real(path[1]);
if (single_real_path) {
    path[2] = path[1];
    path[1] = "default";
    pc = 2;
}

// Stop if _json_dig() errors out
var current = _json_dig(argument[0], path, 1);
if (path[0] <= 0) {
    return path[0];
}
// Check type of subdata
var to_nest = argument[argument_count-1],
    nested_is_list = ds_map_size(to_nest) == 1 && ds_map_exists(to_nest, "default");

// Set the last layer and go
var k = path[pc];
if (is_string(k) && !_json_not_ds(current, ds_type_map)) {
    if (nested_is_list) {
        ds_map_add_list(current, k, to_nest[? "default"]);
    } else {
        ds_map_add_map(current, k, to_nest);
    }
} else if (is_real(k) && !_json_not_ds(current, ds_type_list)) {
    if (nested_is_list) {
        current[| k] = to_nest[? "default"];
        ds_list_mark_as_list(current, k);
    } else {
        current[| k] = to_nest;
        ds_list_mark_as_map(current, k);
    }
} else {
    if (single_real_path) {
        return -1;
    }
    return -pc;
}

// Success!
return 1;


#define json_insert
///json_insert(@jsonstruct, ..., value)
if (argument_count < 3) {
    show_error("Expected at least 3 arguments, got " + string(argument_count) + ".", true);
}

// Build the seek path
var path = array_create(argument_count-1),
    pc = 0;
for (var i = 1; i < argument_count-1; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[++pc] = argi[j];
        }
    } else {
        path[++pc] = argi;
    }
}
// Special: Dig at least to default if only path value is real
var single_real_path = pc == 1 && (is_real(path[1]) || is_undefined(path[1]));
if (single_real_path) {
    path[2] = path[1];
    path[1] = "default";
    pc = 2;
}

// Stop if _json_dig() errors out
var current = _json_dig(argument[0], path, 1);
if (path[0] <= 0) {
    return path[0];
}

// Insert at the last layer and go
var k = path[pc];
if (is_string(k) && !_json_not_ds(current, ds_type_map)) {
    current[? k] = argument[argument_count-1];
    return 1;
} else if (!_json_not_ds(current, ds_type_list)) {
    if (is_real(k)) {
        ds_list_insert(current, k, argument[argument_count-1]);
        return 1;
    } else if (is_undefined(k)) {
        ds_list_add(current, argument[argument_count-1]);
        return 1;
    }
}

// None of the inserts work
if (single_real_path) {
    return -1;
}
return -pc;


#define json_insert_nested
///json_insert_nested(@jsonstruct, ..., jsonsubdata)
if (argument_count < 3) {
    show_error("Expected at least 3 arguments, got " + string(argument_count) + ".", true);
}
var current = argument[0];

// Build the seek path
var path = array_create(argument_count-1),
    pc = 0;
for (var i = 1; i < argument_count-1; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[++pc] = argi[j];
        }
    } else {
        path[++pc] = argi;
    }
}
// Special: Dig at least to default if only path value is real or undefined
var single_real_path = pc == 1 && (is_real(path[1]) || is_undefined(path[1]));
if (single_real_path) {
    path[2] = path[1];
    path[1] = "default";
    pc = 2;
}

// Stop if _json_dig() errors out
var current = _json_dig(argument[0], path, 1);
if (path[0] <= 0) {
    return path[0];
}

// Check type of subdata
var to_nest = argument[argument_count-1],
    nested_is_list = ds_map_size(to_nest) == 1 && ds_map_exists(to_nest, "default");

// Set the last layer and go
var k = path[pc];
if (is_string(k) && !_json_not_ds(current, ds_type_map)) {
    if (nested_is_list) {
        ds_map_add_list(current, k, to_nest[? "default"]);
    } else {
        ds_map_add_map(current, k, to_nest);
    }
    return 1;
} else if (!_json_not_ds(current, ds_type_list)) {
    if (is_real(k)) {
        if (nested_is_list) {
            ds_list_insert(current, k, ds_map_find_value(to_nest, "default"));
        } else {
            ds_list_insert(current, k, to_nest);
        }
    } else if (is_undefined(k)) {
        k = ds_list_size(current);
        if (nested_is_list) {
            ds_list_add(current, ds_map_find_value(argument[argument_count-1], "default"));
        } else {
            ds_list_add(current, argument[argument_count-1]);
        }
    } else {
        if (single_real_path) {
            return -1;
        }
        return -pc;
    }
    if (nested_is_list) {
        ds_list_mark_as_list(current, k);
    } else {
        ds_list_mark_as_map(current, k);
    }
    return 1;
}

// None of the inserts work
if (single_real_path) {
    return -1;
}
return -pc;


#define json_unset
///json_unset(@jsonstruct, ...)
if (argument_count < 2) {
    show_error("Expected at least 2 arguments, got " + string(argument_count) + ".", true);
}

// Build the seek path
var path = array_create(argument_count),
    pc = 0;
for (var i = 1; i < argument_count; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[++pc] = argi[j];
        }
    } else {
        path[++pc] = argi;
    }
}
// Special: Dig at least to default if only path value is real
var single_real_path = pc == 1 && is_real(path[1]);
if (single_real_path) {
    path[2] = path[1];
    path[1] = "default";
    pc = 2;
}

// Stop if _json_dig() errors out
var current = _json_dig(argument[0], path, 1);
if (path[0] <= 0) {
    return path[0];
}

// Set the last layer and go
if (is_string(k)) {
    ds_map_delete(current, k);
} else {
    ds_list_delete(current, k);
}
return 1;


#define json_clone
///json_clone(jsonstruct)
return json_decode(json_encode(argument0));


#define json_destroy
///json_destroy(@jsonstruct)
ds_map_destroy(argument0);


#define json_load
///json_load(fname)
if (file_exists(argument0)) {
    var f = file_text_open_read(argument0),
        jsonstr = "";
    while (!file_text_eof(f)) {
        jsonstr += file_text_read_string(f);
        file_text_readln(f);
    }
    file_text_close(f);
    return json_decode(jsonstr);
}
return undefined;


#define json_save
///json_save(fname, jsonstruct)
var f = file_text_open_write(argument0);
if (ds_map_exists(argument1, "default") && !_json_not_ds(argument1[? "default"], ds_type_list)) {
    file_text_write_string(f, json_encode_as_list(argument1));
} else {
    file_text_write_string(f, json_encode(argument1));
}
file_text_close(f);


#define json_iterate
///json_iterate(jsonstruct, ..., type)
if (argument_count < 2) {
    show_error("Expected at least 2 arguments, got " + string(argument_count) + ".", true);
}
enum JSONITER {
    VALUE,
    KEY,
    DS
}

// Build the seek path
var path = array_create(argument_count-1),
    pc = 0;
for (var i = 1; i < argument_count-1; i++) {
    var argi = argument[i];
    if (is_array(argi)) {
        var jsize = array_length_1d(argi);
        for (var j = 0; j < jsize; j++) {
            path[++pc] = argi[j];
        }
    } else {
        path[++pc] = argi;
    }
}
// Special: Dig at least to default if only path value is real
var single_real_path = pc == 1 && is_real(path[1]);
if (single_real_path) {
    path[2] = path[1];
    path[1] = "default";
    pc = 2;
}

// Stop if _json_dig() errors out
var ds = _json_dig(argument[0], path, 0);
if (path[0] <= 0) {
    return path[0];
}

// Create the iterator
var iterator = array_create(3);
iterator[JSONITER.DS] = ds;
if (_json_not_ds(ds, ds_type_map)) return undefined;
if (pc > 1) {
    switch (argument[argument_count-1]) {
        case ds_type_map:
            if (ds_map_empty(ds)) {
                iterator[JSONITER.VALUE] = undefined;
                iterator[JSONITER.KEY] = undefined;
            } else {
                var k = ds_map_find_first(ds);
                iterator[JSONITER.KEY] = k;
                iterator[JSONITER.VALUE] = ds[? k];
            }
            break;
        case ds_type_list:
            iterator[JSONITER.KEY] = 0;
            if (ds_list_empty(ds)) {
                iterator[JSONITER.VALUE] = undefined;
            } else {
                iterator[JSONITER.VALUE] = ds[| 0];
            }
            break;
        default:
            show_error("Invalid iteration type.", true);
    }
} else {
    switch (argument[argument_count-1]) {
        case ds_type_map:
            iterator[JSONITER.DS] = ds;
            if (ds_map_empty(ds)) {
                iterator[JSONITER.VALUE] = undefined;
                iterator[JSONITER.KEY] = undefined;
            } else {
                var k = ds_map_find_first(ds);
                iterator[JSONITER.KEY] = k;
                iterator[JSONITER.VALUE] = ds[? k];
            }
            break;
        case ds_type_list:
            if (!ds_map_exists(ds, "default")) return undefined;
            ds = ds[? "default"];
            if (_json_not_ds(ds, ds_type_list)) return undefined;
            iterator[JSONITER.DS] = ds;
            iterator[JSONITER.KEY] = 0;
            if (ds_list_empty(ds)) {
                iterator[JSONITER.VALUE] = undefined;
            } else {
                iterator[JSONITER.VALUE] = ds[| 0];
            }
            break;
        default:
            show_error("Invalid iteration type.", true);
    }
}
return iterator;


#define json_has_next
///json_has_next(jsoniterator)
if (!is_array(argument0) || is_undefined(argument0[JSONITER.KEY])) return false;
var k = argument0[JSONITER.KEY];
if (is_real(k)) return k < ds_list_size(argument0[JSONITER.DS]);
if (is_string(k)) return ds_map_exists(argument0[JSONITER.DS], k);
show_error("Unexpected error when iterating: " + string(argument0), true);


#define json_next
///json_next(@jsoniterator)
if (!is_array(argument0) || is_undefined(argument0[JSONITER.KEY])) return false;
var k = argument0[JSONITER.KEY];
if (is_real(k)) {
    if (++argument0[@JSONITER.KEY] < ds_list_size(argument0[JSONITER.DS])) {
        argument0[@JSONITER.VALUE] = ds_list_find_value(argument0[JSONITER.DS], argument0[JSONITER.KEY]);
    } else {
        argument0[@JSONITER.VALUE] = undefined;
    }
} else if (is_string(k)) {
    argument0[@JSONITER.KEY] = ds_map_find_next(argument0[JSONITER.DS], k);
    if (is_undefined(argument0[JSONITER.KEY])) {
        argument0[@JSONITER.VALUE] = undefined;
    } else {
        argument0[@JSONITER.VALUE] = ds_map_find_value(argument0[JSONITER.DS], argument0[JSONITER.KEY]);
    }
} else {
    show_error("Unexpected error when iterating: " + string(argument0), true);
}


#define _json_not_ds
gml_pragma("forceinline");
return !(is_real(argument0) && ds_exists(argument0, argument1));
#define _json_dig
///_json_dig(jsonstruct, @seekpath, ignore_last_n)
//seekpath is always [blank, ...<path>...]; first slot will receive a status from this function
var current = argument0,
    path = argument1,
    ignore_last = argument2,
    spsiz = array_length_1d(path)-ignore_last;

// Check existence of top
if (_json_not_ds(current, ds_type_map)) {
    path[@ 0] = 0;
    return undefined;
}
// If path is "empty", return the top
if (spsiz <= 1) {
  path[@ 0] = 1;
  return current;
}
// Check existence of first layer
var k = path[1];
if (is_string(k)) {
    if (!ds_map_exists(current, k)) {
        path[@ 0] = -1;
        return undefined;
    }
    current = current[? k];
} else if (is_real(k)) {
    if (!ds_map_exists(current, "default")) {
        path[@ 0] = -1;
        return undefined;
    }
    current = current[? "default"];
    if (_json_not_ds(current, ds_type_list)) {
        path[@ 0] = -1;
        return undefined;
    }
    if (k >= ds_list_size(current)) {
        path[@ 0] = -1;
        return undefined;
    }
    current = current[| k];
} else {
    path[@ 0] = -1;
    return undefined;
}
// Check existence of subsequent layers
for (var i = 2; i < spsiz; i++) {
    k = path[i];
    if (is_string(k)) {
        if (_json_not_ds(current, ds_type_map) || !ds_map_exists(current, k)) {
          path[@ 0] = -i;
          return undefined;
        }
        current = current[? k];
    } else if (is_real(k)) {
        if (_json_not_ds(current, ds_type_list) || k >= ds_list_size(current)) {
          path[@ 0] = -i;
          return undefined;
        }
        current = current[| k];
    } else {
        path[@ 0] = -i;
        return undefined;
    }
}
// Mark the path as OK
path[@ 0] = 1;
// Return dig result
return current;