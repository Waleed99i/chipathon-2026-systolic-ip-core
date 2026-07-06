#include <vpi_user.h>

PLI_INT32 shortrealtobits_calltf(char *user_data) {
    vpiHandle systf_handle, arg_iter, arg_handle;
    s_vpi_value arg_value, rtn_value;

    systf_handle = vpi_handle(vpiSysTfCall, NULL);
    arg_iter = vpi_iterate(vpiArgument, systf_handle);
    arg_handle = vpi_scan(arg_iter);

    // Read argument as a real number
    arg_value.format = vpiRealVal;
    vpi_get_value(arg_handle, &arg_value);

    // Convert to float, then read as integer
    float f = (float)arg_value.value.real;
    union { float f; unsigned int i; } u;
    u.f = f;

    // Return as integer
    rtn_value.format = vpiIntVal;
    rtn_value.value.integer = u.i;
    vpi_put_value(systf_handle, &rtn_value, NULL, vpiNoDelay);

    vpi_free_object(arg_iter);
    return 0;
}

void shortrealtobits_register(void) {
    s_vpi_systf_data tf_data;
    tf_data.type = vpiSysFunc;
    tf_data.sysfunctype = vpiIntFunc; // Returns an Integer
    tf_data.tfname = "$shortrealtobits";
    tf_data.calltf = shortrealtobits_calltf;
    tf_data.compiletf = NULL;
    tf_data.sizetf = NULL;
    tf_data.user_data = NULL;
    vpi_register_systf(&tf_data);
}

PLI_INT32 bitstoshortreal_calltf(char *user_data) {
    vpiHandle systf_handle, arg_iter, arg_handle;
    s_vpi_value arg_value, rtn_value;

    systf_handle = vpi_handle(vpiSysTfCall, NULL);
    arg_iter = vpi_iterate(vpiArgument, systf_handle);
    arg_handle = vpi_scan(arg_iter);

    arg_value.format = vpiIntVal;
    vpi_get_value(arg_handle, &arg_value);

    union { float f; unsigned int i; } u;
    u.i = arg_value.value.integer;

    double d = (double)u.f;

    rtn_value.format = vpiRealVal;
    rtn_value.value.real = d;
    vpi_put_value(systf_handle, &rtn_value, NULL, vpiNoDelay);

    vpi_free_object(arg_iter);
    return 0;
}

void bitstoshortreal_register(void) {
    s_vpi_systf_data tf_data;
    tf_data.type = vpiSysFunc;
    tf_data.sysfunctype = vpiRealFunc;
    tf_data.tfname = "$bitstoshortreal";
    tf_data.calltf = bitstoshortreal_calltf;
    tf_data.compiletf = NULL;
    tf_data.sizetf = NULL;
    tf_data.user_data = NULL;
    vpi_register_systf(&tf_data);
}

void (*vlog_startup_routines[])() = {
    shortrealtobits_register,
    bitstoshortreal_register,
    0
};