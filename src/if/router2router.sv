import noc_pkg::*;

interface router2router;

    noc_pkg::flit_t data;
    logic is_valid;
    logic [noc_pkg::VC_NUM-1:0] is_on_off;
    logic [noc_pkg::VC_NUM-1:0] is_allocatable;

    modport upstream (
        output data,
        output is_valid,
        input is_on_off,
        input is_allocatable
    );

    modport downstream (
        input data,
        input is_valid,
        output is_on_off,
        output is_allocatable
    );

endinterface