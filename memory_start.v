module memory_start (
	input writeEn,
	input resetn,
	input clk,
	output reg [8:0] x,
	output reg [8:0] y,
	output [5:0] colour,
	
//	input      [0:0] SW           ,
//	input      [0:0] KEY          ,
//	input            CLOCK_50     ,
//	output           VGA_CLK      , //	VGA Clock
//	output           VGA_HS       , //	VGA H_SYNC
//	output           VGA_VS       , //	VGA V_SYNC
//	output           VGA_BLANK_N  , //	VGA BLANK
//	output           VGA_SYNC_N   , //	VGA SYNC
//	output     [7:0] VGA_R        , //	VGA Red[7:0] Changed from 10 to 8-bit DAC
//	output     [7:0] VGA_G        , //	VGA Green[7:0]
//	output     [7:0] VGA_B        , //	VGA Blue[7:0]
	output reg       done_plotting
);

	//wire writeEn;
	//wire resetn ;
	//wire clk    ;


	reg [16:0] address;
	//reg [ 8:0] x      ;
	reg [ 8:0] x_start;
	//reg [7:0] y; 
	reg [7:0]y_start;
	reg [16:0] counter;


	//assign writeEn = SW[0];
	//assign resetn  = KEY[0];
	//assign clk     = CLOCK_50;



	always@(posedge clk) begin
		done_plotting <= 0;

		if(!resetn) begin
			x_start <= 0;
			y_start <= 0;
			counter <= 0;
			address <= 0;
		end

		else if(writeEn) begin
			if(counter[16:9]==8'd240) begin
				done_plotting <= 1;
				x_start <= 0;
				y_start <= 0;
				counter <= 0;
				address <= 0;
			end
			else if(counter[8:0]<9'd319)begin
				counter <= counter+1;
				address <= address + 1;
			end
			else if(counter[8:0]==9'd319) begin
				counter[16:9] <= counter[16:9]+1;
				counter[8:0] <= 0;
				address <= address + 1;
			end
		end // else if(writeEn)
	end // always@(posedge clk)

	always@(*)begin
		x <= x_start + counter[8:0];
		y <= y_start + counter[16:9];
	end

	ROM_start b1 (
		.address(address),
		.clock  (clk  ),
		.q      (colour )
	);




endmodule