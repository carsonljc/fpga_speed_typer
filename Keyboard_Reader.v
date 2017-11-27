module Keyboard_Reader (
	// Inputs
	input            CLOCK_50, // Clock
	//input reset,
	//input start_read,
	input      [3:0] KEY     ,
	//input            ps2_key_pressed,
	//input      [7:0] ps2_key_data   ,
	// Bidirectionals
	inout            PS2_CLK ,
	inout            PS2_DAT ,
	// Outputs
	output reg [9:0] LEDR    ,
	output     [6:0] HEX0    ,
	output     [6:0] HEX2    ,
	output     [6:0] HEX4
);

/*****************************************************************************
	*                           Parameter Declarations                          *
	*****************************************************************************/

/*****************************************************************************
	*                             Port Declarations                             *
	*****************************************************************************/

/*****************************************************************************
	*                           Constant Declarations                           *
	*****************************************************************************/

	// states
	localparam
		READER_STATE_0_WAIT = 4'd0,
		READER_STATE_1_NEW = 4'd1,
		READER_STATE_2_IDLE = 4'd2,
		READER_STATE_3_READ = 4'd3,
		READER_STATE_4_COMPARE = 4'd4,
		READER_STATE_5_MATCH = 4'd5,
		READER_STATE_6_CHECK = 4'd6,
		READER_STATE_7_OUTPUT = 4'd7,
		READER_STATE_8_FAIL = 4'd8,
		RESET_GAME = 4'd9;

/*****************************************************************************
	*                 Internal wires and registers Declarations                 *
	*****************************************************************************/

	// Internal Wires
	wire       resetn           ;
	reg        enable_next_level;
	wire       ps2_key_pressed  ;
	wire [7:0] ps2_key_data     ;
	wire       clk              ;
	wire       timer_done       ;
	wire [7:0] num_char         ;
	wire       start_read       ;
	reg        ld_difficulty    ;
	wire [1:0] difficulty       ;
	// wire [87:0]sequence;
	// Internal Registers
	reg        finished               ;
	reg        enable_timer           ;
	reg  [1:0] debouncing_count       ;
	reg        failed_input           ;
	reg        writeEn                ;
	reg        correct_data_received  ;
	reg        get_next_character     ;
	reg  [7:0] total_keystroke_count  ;
	wire [7:0] comparison_data        ;
	reg  [7:0] last_data_received     ;
	reg  [3:0] current_state          ;
	reg  [3:0] next_state             ;
	reg  [7:0] correct_keystroke_count;
	reg        game_reset             ;
	reg        board_resetn           ;

/*****************************************************************************
	*                         Finite State Machine(s)                           *
	*****************************************************************************/

	always @(*) begin : state_table
		case (current_state)
			//state that is only active on when reset, to select the difficulty
			READER_STATE_SELECT_DIFFICULTY : 
				begin
					next_state = (last_data_received == 8'h16 || last_data_received == 8'h1E || last_data_received == 8'h26) ? READER_STATE_0_WAIT : READER_STATE_SELECT_DIFFICULTY;
				end
			//state to wait for the user to start the game, waits until the user presses <enter> to start
			READER_STATE_0_WAIT : next_state = (last_data_received == 8'h5A) ? READER_STATE_1_NEW : READER_STATE_0_WAIT;
			//loads a new level
			READER_STATE_1_NEW  : next_state = READER_STATE_DRAW_SEQUENCE_ON_SCREEN;
			//sets the registers to start printing a sequence on the screen
			READER_STATE_DRAW_SEQUENCE_ON_SCREEN : next_state = READER_STATE_WAIT_SEQUENCE_ON_SCREEN;
			//waits until the sequence has been printed on the screen
			READER_STATE_WAIT_SEQUENCE_ON_SCREEN : next_state = (ready_to_plot_sequence) ? READER_STATE_2_IDLE : READER_STATE_WAIT_SEQUENCE_ON_SCREEN;
			//waits until the user presses a button to start the timer and reading of the game
			READER_STATE_2_IDLE :
				begin
					if (timer_done)
						next_state = READER_STATE_8_FAIL;
					else
						next_state = (ps2_key_pressed) ? READER_STATE_3_READ : READER_STATE_2_IDLE;
				end
			//accepts input
			READER_STATE_3_READ :
				begin
					next_state = READER_STATE_4_COMPARE;
				end
			//compares the input
			READER_STATE_4_COMPARE :
				begin
					next_state = (last_data_received == comparison_data) ? READER_STATE_5_MATCH : READER_STATE_2_IDLE;
				end
			//input matches
			READER_STATE_5_MATCH :
				begin
					next_state = READER_STATE_6_CHECK;
				end
			//check if all possible have been entered
			READER_STATE_6_CHECK :
				begin
					next_state = (correct_keystroke_count == num_char) ? READER_STATE_7_OUTPUT : READER_STATE_2_IDLE;
				end
			//if the user has entered a correct sequence then we print out a level screen
			READER_STATE_7_OUTPUT :
				begin
					next_state = READER_STATE_0_WAIT;
				end
			//user failed, wait for reset
			READER_STATE_8_FAIL :
				begin
					next_state = (last_data_received == 8'h5A) ? RESET_GAME : READER_STATE_8_FAIL;
				end
			RESET_GAME : next_state = READER_STATE_SELECT_DIFFICULTY;
			default : next_state = READER_STATE_0_WAIT;
		endcase // current_state
	end

	always @(*) begin : enable_signals
		get_next_character    = 1'b0;
		writeEn               = 1'b0;
		correct_data_received = 1'b0;
		failed_input          = 1'b0;
		enable_next_level     = 1'b0;
		finished              = 1'd0;
		enable_draw_sequence  = 1'b0;
		ld_difficulty 		  = 1'b0;
		game_reset    		  = 1'b0;
		case (current_state)
			READER_STATE_SELECT_DIFFICULTY:
				begin
					ld_difficulty = 1'b1; 
				end
			READER_STATE_0_WAIT :
				begin
					finished = 1'b1;
				end
			READER_STATE_1_NEW :
				begin
					enable_next_level = 1'b1;
				end
			READER_STATE_DRAW_SEQUENCE_ON_SCREEN :
				begin
					finished = 1'b1;
					enable_draw_sequence = 1'b1;
				end
			READER_STATE_WAIT_SEQUENCE_ON_SCREEN :
				begin
				end
			READER_STATE_3_READ :
				begin
					//get_next_character = 1'b1;
				end
			READER_STATE_5_MATCH :
				begin
					if(last_data_received == comparison_data) begin
						correct_data_received = 1'b1;
						get_next_character    = 1'b1;
					end
				end
			READER_STATE_7_OUTPUT :
				begin
					writeEn = 1'b1;
				end
			READER_STATE_8_FAIL :
				begin
					failed_input = 1'd1;
				end
			RESET_GAME : 
				begin
					game_reset = 1'd1;
				end
		endcase // current_state
	end


/*****************************************************************************
	*                             Sequential logic                              *
	*****************************************************************************/

	always @ (posedge clk) begin : state_change
		if(!resetn) begin
			current_state <= READER_STATE_0_WAIT;
		end
		else begin
			current_state <= next_state;
		end
	end

	always @(posedge clk) begin
		if(!resetn||finished) begin
			correct_keystroke_count <= 0;
		end
		else if (correct_data_received) begin
			//&& debouncing_count == 2'd2
			correct_keystroke_count <= correct_keystroke_count + 1;
		end
	end

	always @(posedge clk) begin
		if (!resetn||finished) begin
			debouncing_count      <= 2'd0;
			last_data_received    <= 8'h00;
			total_keystroke_count <= 0;
			enable_timer          <= 0;
		end
		else if (ps2_key_pressed == 1'b1 && debouncing_count==2'd2) begin
			debouncing_count      <= 0;
			total_keystroke_count <= total_keystroke_count + 1;
		end
		else if (ps2_key_pressed == 1'b1) begin
			last_data_received <= ps2_key_data;
			enable_timer       <= 1;
			debouncing_count   <= debouncing_count + 1'b1;
		end
	end

	always@(posedge clk) begin
		if(ps2_key_pressed == 1'b1) begin
			if(last_data_received == 8'h16)
				difficulty <= 1;
			else if (last_data_received == 8'h1E)
				difficulty <= 2;
			else if (last_data_received == 8'h26)
				difficulty <= 3;
		end // if(ps2_key_pressed == 1'b1)
		else
			difficulty <= 0;
	end // always@(posedge clk)

	always@(posedge clk)begin
		resetn = 1'd1;
		if(game_reset || board_resetn)
			resetn = 1'd0;
	end

/*****************************************************************************
	*                            Combinational logic                            *
	*****************************************************************************/
	assign board_resetn = KEY[0];
	assign clk = CLOCK_50;

/*****************************************************************************
	*                              Internal Modules                             *
	*****************************************************************************/

	PS2_Controller PS2 (
		// Inputs
		.CLOCK_50        (clk            ),
		.reset           (!resetn        ),
		// Bidirectionals
		.PS2_CLK         (PS2_CLK        ),
		.PS2_DAT         (PS2_DAT        ),
		//Outputs
		.received_data   (ps2_key_data   ),
		.received_data_en(ps2_key_pressed)
	);

	// Keyboard_Input_Shift i_KeyBoard_Input_Shift (
	// 	.num_char          (char_num          ),
	// 	.sequence          (sequence          ),
	// 	.resetn            (resetn            ),
	// 	.get_next_character(get_next_character),
	// 	.clk               (clk               ),
	// 	.char_num          (char_num          ),
	// 	.comparison_data   (comparison_data   )
	// );

	hex_decoder i_hex_decoder0 (
		.hex_digit(correct_keystroke_count[3:0]),
		.segments (HEX0                        )
	);

	hex_decoder i_hex_decoder1 (
		.hex_digit(total_keystroke_count[3:0]),
		.segments (HEX2                      )
	);

	hex_decoder i_hex_decoder2 (
		.hex_digit(current_state),
		.segments (HEX4         )
	);

	Keyboard_Parser i_Keyboard_Parser_Modifier (
		.clk               (clk               ),
		.resetn            (resetn            ),
		.get_next_character(get_next_character),
		.enable_next_level (enable_next_level ),
		.num_char          (num_char          ),
		.comparison_data   (comparison_data   )
	);


	timer_3s i_timer_3s (
		.clk              (clk              ),
		.q                (timer_done       ),
		.enable_next_level(enable_next_level),
		.enable           (enable_timer     ),
		.num_char         (num_char         ),
		.resetn           (resetn           )
	);
endmodule


