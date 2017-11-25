module Keyboard_Parser (
	input        clk               ,
	input        resetn            ,
	input        get_next_character,
	input        enable_next_level ,
	output [7:0] num_char          ,
	output [7:0] comparison_data   

);

	wire [87:0] sequence_;
	wire load_sequence;

Keyboard_Input_Shift i_Keyboard_Input_Shift (
	.clk               (clk               ),
	.sequence_          (sequence_        ),
	.resetn            (resetn            ),
	.load_sequence     (load_sequence     ),
	.get_next_character(get_next_character),
	.comparison_data   (comparison_data   )
);

next_level i_next_level (
	.clk              (clk              ),
	.resetn           (resetn           ),
	.enable_next_level(enable_next_level),
	.load_sequence    (load_sequence    ),
	.sequence_      (sequence_      ),
	.num_char         (num_char         )
);

endmodule



module Keyboard_Input_Shift (
	input         clk               ,
	input  [87:0] sequence_         ,
	input         resetn            ,
	input         load_sequence     ,
	input         get_next_character,
	output [7:0] comparison_data	  

);

		reg [87:0] sequence_data;

		always @(posedge clk) begin : sequence_left_shift
			if (!resetn) begin
				sequence_data <= 0;
			end
			//get_next_character has higher priority but may cause unwanted effects
			//between level changes where get = 0 and load = 1
			else if (get_next_character) begin
				sequence_data <= (sequence_data<<8);
			end
			else if (load_sequence) begin
				sequence_data <= sequence_;
			end
		end
		
//		always@(negedge load_sequence) begin
//		if (load_sequence)
//		sequence_data<=sequence_;
//		end

		assign comparison_data = sequence_data[87:80];
		
		

endmodule



module next_level (
	input             clk              ,
	input             resetn           ,
	input             enable_next_level,
	output reg        load_sequence    ,
	output reg [87:0] sequence_        ,
	output reg [ 7:0] num_char			  	
);

		reg [2:0] current_state, next_state;
		reg get_sequence;
		localparam
		S_WAIT_START = 3'd0,
		S_LOAD_NEXT  = 3'd1,
		S_LOAD_WAIT	 = 3'd2,
		S_GET_SEQUENCE = 3'd3,
//		S_LOAD_SEQ_1 = 3'd1,
//		S_WAIT_SEQ_1 = 3'd2,
//		S_LOAD_SEQ_2 = 3'd3,
//		S_WAIT_SEQ_2 = 3'd4,
//		S_LOAD_SEQ_3 = 3'd5,
//		S_WAIT_SEQ_3 = 3'd6,
		 HELLO       = 88'h33_24_4B_4B_44_00_00_00_00_00_00,
		 DIFFERENTIAL= 88'h23_43_2B_2B_24_2D_24_31_2C_43_1C_4B_4B;
		 VERILOG     = 88'h2A_24_2D_43_4B_44_34_00_00_00_00,
		 UNIVERSITY  = 88'h3C_31_43_2A_24_2D_1B_43_2C_35_00,
		 ENGINEERING = 88'h24_31_34_43_31_24_24_2D_43_31_34,

		 
	reg [3:0]address=4'd0;
	always @(*) begin : state_table
		case (current_state)
			S_WAIT_START : next_state = (enable_next_level) ? S_LOAD_NEXT : S_WAIT_START;

			
			S_LOAD_NEXT	 : next_state = S_LOAD_WAIT;
			S_LOAD_WAIT  : next_state = (enable_next_level) ? S_GET_SEQUENCE : S_LOAD_WAIT;
			S_GET_SEQUENCE : next_state = S_LOAD_NEXT;
//			S_LOAD_SEQ_1 : next_state = S_WAIT_SEQ_1;
//			S_WAIT_SEQ_1 : next_state = (enable_next_level) ? S_LOAD_SEQ_2 : S_WAIT_SEQ_1;
//			S_LOAD_SEQ_2 : next_state = S_WAIT_SEQ_2;
//			S_WAIT_SEQ_2 : next_state = (enable_next_level) ? S_LOAD_SEQ_3 : S_WAIT_SEQ_2;
//			S_LOAD_SEQ_3 : next_state = S_WAIT_SEQ_3;
			default    : next_state = S_WAIT_START;
		endcase
	end

	always @(*) begin : enable_signals
		load_sequence = 1'd0;
    	get_sequence = 1'b0;
		case (current_state) 
		S_GET_SEQUENCE : begin
			get_sequence = 1'b1;
		end
   	S_LOAD_NEXT: begin
		load_sequence = 1'd1;
		
		end
//    	S_LOAD_SEQ_1 : begin
//        	sequence = HELLO;
//			num_char = 8'h05;
//			load_sequence = 1'd1;
//        end
//        S_WAIT_SEQ_1 : begin
//        	sequence = HELLO;
//			num_char = 8'h05;
//		end
//       	S_LOAD_SEQ_2 : begin
//         	sequence = VERILOG;
//			num_char = 8'h07;
//			load_sequence = 1'd1;
//        end
//        S_WAIT_SEQ_2 : begin
//        	sequence = VERILOG;
//			num_char = 8'h07;
//        end
//      	S_LOAD_SEQ_3 : begin
//         	sequence = ENGINEERING;
//			num_char = 8'h0B;
//			load_sequence = 1'd1;
//        end		
//        S_WAIT_SEQ_3  : begin
//			sequence = ENGINEERING;
//			num_char = 8'h0B;
//        end
    endcase // current_state
  end

  //reg first=0;
  always @(posedge clk) 
  begin 
  if (!resetn)
  address<=0;
	if (get_sequence==1'b1 && resetn  )
		address<=address+4'b1;
  end
  
	// current_state registers
	always@(posedge clk)
		begin : state_FFs
			if(!resetn)
				current_state <= S_WAIT_START;
			else
				current_state <= next_state;
		end // state_FFS
		
		
		
	always @(*) begin

	case(address)


	4'd0:begin
	sequence_=HELLO;
	num_char = 8'h05;
	//first =1;
	end
	4'd1:begin
	sequence_=VERILOG;
	num_char = 8'h07;
	end
   4'd2:begin
	sequence_=UNIVERSITY;
		num_char = 8'h0A;
	end
	
	
   4'd3:begin
	sequence_=ENGINEERING;
		num_char = 8'h0B;
	end
//   4'd4:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
//	   4'd5:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
//	   4'd6:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
//	   4'd7:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
//	   4'd8:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
//	   4'd9:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
//	   4'd10:begin
//	sequence_=ENGINEERING;
//		num_char = 8'h0B;
//	end
	default:begin
		sequence_=HELLO;
	num_char = 8'h05;
	end
	endcase
	end


endmodule