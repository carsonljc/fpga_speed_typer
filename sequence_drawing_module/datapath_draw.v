omodule datapath_draw (
	input             clk                 ,
	input             resetn              ,
	input      [ 5:0] colour_input        ,
	input      [ 8:0] y_input             ,
	input      [ 8:0] x_input             ,
	input             ld_block            ,
	input             ld_black            ,
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

	// input registers


	// Registers x, y, colour with respective input logic
	always@(posedge clk) begin
		if(!resetn) begin
			x      <= 9'b0;
			y      <= 9'b0;
			colour <= 6'b0;
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
				colour  <= colour_input;
			end
			//change lower half to black
			if(ld_black) begin
				x       <= 9'b0;
				y       <= 9'b0;
				//change x_start to 105 to take up the bottom 35 pixels
				x_start <= 9'd10;
				y_start <= 9'd200;
				//black
				colour  <= 6'b000;
			end
			//incrementing the counter for drawing a square
			if(enable_counter) begin
				counter <= counter + 1;
				x       <= x_start + counter[1:0];
				y       <= y_start + counter[3:2];
			end
			//incrementing the counter for clearing screen
			if(enable_clear_counter) begin
				clear_counter <= clear_counter + 1;
				x             <= x_start + clear_counter[7:0];
				y             <= y_start + clear_counter[14:8];
			end
		end
	end // always@(posedge clk)
endmodule