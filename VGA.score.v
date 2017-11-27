module VGA_score(
    input        clk                     , // Clock
    input        resetn                  , // Asynchronous reset active low
    input        enable_start   , // starts plot of character
    input  [8:0] x_input                 ,
    input  [8:0] y_input                 ,
    input        enable_clear                  
);


    wire [5:0] colour_input;
    wire ld_white;
    reg [8:0] x;
    reg [8:0] y;
    reg [5:0] colour=6'b001001;

    
datapath_draw i_datapath_draw (
    .clk                 (clk                 ),
    .resetn              (resetn              ),
    .colour_input        (colour_input        ),
    .y_input             (y_input             ),
    .x_input             (x_input             ),
    .ld_white            (ld_white            ),
    .enable_counter      (enable_counter      ),
    .reset_counter       (reset_counter       ),
    .enable_clear_counter(enable_clear_counter),
    .clear_counter       (clear_counter       ), // TODO: Check connection ! Incompatible port direction (not an input)
    .counter             (counter             ), // TODO: Check connection ! Incompatible port direction (not an input)
    .x                   (x                   ),
    .y                   (y                   ),
    .colour              (colour              )
);





control_draw i_control_draw (
    .clk                 (clk                 ),
    .resetn              (resetn              ),
    .enable_start        (enable_start        ),
    .enable_clear        (enable_clear        ),
    .counter             (counter             ),
    .clear_counter       (clear_counter       ),
    .ld_white            (ld_white            ),
    .ready_to_draw       (ready_to_draw       ),
    .enable_counter      (enable_counter      ),
    .reset_counter       (reset_counter       ),
    .enable_clear_counter(enable_clear_counter)
);



//need vga drawing








//001001 green bar  
00b567
module control_draw (
    input             clk                 ,
    input             resetn              ,
    input             enable_start        ,
    input             enable_clear        ,
    input      [ 4:0] counter             ,
    input      [15:0] clear_counter       ,
   output reg        ld_white            ,
    output reg        ready_to_draw       ,
   // output reg        ld_block            ,
  //  output reg        writeEn             ,
    output reg        enable_counter      ,
    output reg        reset_counter       ,
    output reg        enable_clear_counter
);

    reg [4:0] current_state, next_state;

    localparam
        S_WAIT_START = 5'd0,
        S_LOAD_WHITE = 5'd1,
        S_DRAW_WHITE = 5'd2,
        S_DRAW_BLOCK = 5'd3;

    // Next state logic aka our state table
    always@(*)
        begin : state_table
            case (current_state)
                S_WAIT_START :
                    begin
                        if (enable_start)
                            next_state = S_DRAW_BLOCK;
                        else if (enable_clear)
                            next_state = S_LOAD_WHITE;
                        else
                            next_state = S_WAIT_START;
                    end
                
                S_LOAD_WHITE  : next_state = S_DRAW_WHITE;
                S_DRAW_WHITE  : next_state = (clear_counter == 16'd1200) ? S_WAIT_START : S_DRAW_WHITE;
                S_DRAW_BLOCK  : next_state = (counter == 5'd40) ? S_WAIT_START : S_DRAW_BLOCK;
                default       : next_state = S_WAIT_START;
            endcase
        end // state_table

    // Output logic aka all of our datapath control signals
    always @(*)
        begin : enable_signals
            // By default make all our signals 0
            ld_white             = 1'b0;
           // ld_block             = 1'b0;
            writeEn              = 1'b0;
            enable_counter       = 1'b0;
            reset_counter        = 1'b0;
            enable_clear_counter = 1'b0;
            ready_to_draw        = 1'b0;

            case (current_state)
                S_WAIT_START  : begin 
                    ready_to_draw = 1'b1;
                    reset_counter = 1'b1;
                end
                S_LOAD_WHITE : begin
                    ld_white = 1'b1;
                end
                S_DRAW_WHITE : begin
                    writeEn              = 1'b1;
                    ld_white             = 1'b1;
                    enable_clear_counter = 1'b1;
                end
                S_DRAW_BLOCK : begin
                    writeEn        = 1'b1;
                    enable_counter = 1'b1;
                end
                // default:    // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
            endcase
        end // enable_signals

    // current_state registers
    always@(posedge clk)
        begin : state_FFs
            if(!resetn)
                current_state <= S_WAIT_START;
            else
                current_state <= next_state;
        end // state_FFS
endmodule


module datapath_draw (
    input             clk                 ,
    input             resetn              ,
    input      [ 5:0] colour_input        ,
    input      [ 8:0] y_input             ,
    input      [ 8:0] x_input             ,
    //input             ld_block            ,
    input             ld_white            ,
    input             enable_counter      ,
    input             reset_counter       ,
    input             enable_clear_counter,
    output reg [15:0] clear_counter       ,
    output reg [ 4:0] counter             ,
    output reg [ 8:0] x                   ,
    output reg [ 8:0] y                   ,
    output reg [ 5:0] colour
);

    reg [8:0] x_start;
    reg [8:0] y_start;
    reg [5:0]colour_buffer;

    // input registers


    // Registers x, y, colour with respective input logic
    always@(posedge clk) begin
        if(!resetn) begin
            x      <= 9'd0;
            y      <= 9'd0;
            colour <= 6'h;
        end
        else begin
            //resetting the counters for plotting
            if(reset_counter) begin
                counter       <= 5'b0;
                clear_counter <= 16'b0;
            end
            //load the specified coordinate and colour
            if(ld_block) begin
                x_start <= x_input;
                y_start <= y_input;
                colour_buffer  <= colour_input;
            end
            //change lower half to black
            if(ld_white) begin
                x       <= 9'b0;
                y       <= 9'b0;
                //change x_start to 105 to take up the bottom 35 pixels
                x_start <= 9'd10;
                y_start <= 9'd44;
                //black
                colour_buffer  <= 6'b000;
            end
            //incrementing the counter for drawing a square
            if(enable_counter) begin
                counter <= counter + 1;
                x       <= x_start + counter[1:0];
                y       <= y_start + counter[3:2];
                colour   <= colour_buffer;
            end
            //incrementing the counter for clearing screen
            if(enable_clear_counter) begin
                clear_counter <= clear_counter + 1;
                x             <= x_start + clear_counter[7:0];
                y             <= y_start + clear_counter[14:8];
                colour   <= colour_buffer;
            end
        end
    end // always@(posedge clk)
endmodule