///Array(...)
var arr = array_create(argument_count);
for (var i = argument_count-1; i >= 0; i--) {
  arr[i] = argument[i];
}
return arr;

