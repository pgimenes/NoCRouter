import noc_pkg::*;

module mesh #(
    parameter BUFFER_SIZE = 8,
    parameter MESH_SIZE_X = 2,
    parameter MESH_SIZE_Y = 3
)(
    input clk,
    input rst,
    output logic [VC_NUM-1:0] error_o [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0][PORT_NUM-1:0],
    //connections to all local Router interfaces
    output flit_t [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0] data_o,
    output logic [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0] is_valid_o,
    input [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0][VC_NUM-1:0] is_on_off_i,
    input [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0][VC_NUM-1:0] is_allocatable_i,
    input flit_t [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0] data_i,
    input [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0] is_valid_i,
    output logic [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0][VC_NUM-1:0] is_on_off_o,
    output logic [MESH_SIZE_X-1:0][MESH_SIZE_Y-1:0][VC_NUM-1:0] is_allocatable_o
);

router2router local_up   [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router north_up   [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router south_up   [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router west_up    [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router east_up    [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router local_down [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router north_down [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router south_down [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router west_down  [MESH_SIZE_X][MESH_SIZE_Y] ();
router2router east_down  [MESH_SIZE_X][MESH_SIZE_Y] ();

    genvar row, col;
    generate
        for(row=0; row<MESH_SIZE_Y; row++)
        begin: mesh_row
            for(col=0; col<MESH_SIZE_X; col++)
            begin: mesh_col

                //router instantiation
                router #(
                    .BUFFER_SIZE(BUFFER_SIZE),
                    .X_CURRENT(col),
                    .Y_CURRENT(row)
                )
                router (
                    .clk(clk),
                    .rst(rst),
                    //upstream interfaces connections 
                    .router_if_local_up (local_up [col] [row]),
                    .router_if_north_up (north_up [col] [row]),
                    .router_if_south_up (south_up [col] [row]),
                    .router_if_west_up  (west_up  [col] [row]),
                    .router_if_east_up  (east_up  [col] [row]),
                    //downstream interfaces connections
                    .router_if_local_down (local_down [col] [row]),
                    .router_if_north_down (north_down [col] [row]),
                    .router_if_south_down (south_down [col] [row]),
                    .router_if_west_down  (west_down  [col] [row]),
                    .router_if_east_down  (east_down  [col] [row]),
                    .error_o(error_o[col][row])
                );
            end
        end

        for(row=0; row<MESH_SIZE_Y-1; row++)
        begin: vertical_links_row
            for(col=0; col<MESH_SIZE_X; col++)
            begin: vertical_links_col
                router_link link_one (
                    .router_if_up(south_down [col] [row]),
                    .router_if_down(north_up [col] [row+1])
                );

                router_link link_two (
                    .router_if_up(north_down [col] [row+1]),
                    .router_if_down(south_up [col] [row])
                );
                
            end
        end

        for(row=0; row<MESH_SIZE_Y; row++)
        begin: horizontal_links_row
            for(col=0; col<MESH_SIZE_X-1; col++)
            begin: horizontal_links_col
                router_link link_one (
                    .router_if_up(east_down  [col] [row]),
                    .router_if_down(west_up  [col+1] [row])
                );

                router_link link_two (
                    .router_if_up(west_down  [col+1] [row]),
                    .router_if_down(east_up  [col] [row])
                );

            end
        end

        for(row=0; row<MESH_SIZE_Y; row++)
        begin: node_connection_row
            for(col=0; col<MESH_SIZE_X; col++)
            begin: node_connection_col
                node_link node_link (
                    .router_if_up     (local_down       [col] [row]),
                    .router_if_down   (local_up         [col] [row]),
                    .data_i           (data_i           [col] [row]),
                    .is_valid_i       (is_valid_i       [col] [row]),
                    .is_on_off_o      (is_on_off_o      [col] [row]),
                    .is_allocatable_o (is_allocatable_o [col] [row]),
                    .data_o           (data_o           [col] [row]),
                    .is_valid_o       (is_valid_o       [col] [row]),
                    .is_on_off_i      (is_on_off_i      [col] [row]),
                    .is_allocatable_i (is_allocatable_i [col] [row])
                );
            end
        end

    endgenerate

endmodule