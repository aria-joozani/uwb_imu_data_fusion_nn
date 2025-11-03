function new_array = deleteNAN(array)
    nan_array = isnan(array);
    not_nan = ~nan_array;
    new_array = array(not_nan);
end