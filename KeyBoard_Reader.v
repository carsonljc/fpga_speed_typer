module Keyboard_Reader (
	// Inputs
	input        CLOCK_50   , // Clock
	input  [3:0] KEY        ,
	//Signals that are used for simulation
	// input            ps2_key_pressed,
	// input      [7:0] ps2_key_data
	// Bidirectionals
	inout        PS2_CLK    ,
	inout        PS2_DAT    ,
	// OutputsS
	output [9:0] LEDR       ,
	output [6:0] HEX0       ,
	output [6:0] HEX2       ,
	output [6:0] HEX4       ,
	output [6:0] HEX5       ,
	output       VGA_CLK    , //	VGA Clock
	output       VGA_HS     , //	VGA H_SYNC
	output       VGA_VS     , //	VGA V_SYNC
	output       VGA_BLANK_N, //	VGA BLANK
	output       VGA_SYNC_N , //	VGA SYNC
	output [7:0] VGA_R      , //	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output [7:0] VGA_G      , //	VGA Green[7:0]
	output [7:0] VGA_B        //	VGA Blue[7:0]
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
		READER_STATE_0_WAIT = 6'd0,
		READER_STATE_1_NEW = 6'd1,
		READER_STATE_2_IDLE = 6'd2,
		READER_STATE_3_READ = 6'd3,
		READER_STATE_4_COMPARE = 6'd4,
		READER_STATE_5_MATCH = 6'd5,
		READER_STATE_6_CHECK = 6'd6,
		READER_STATE_7_OUTPUT = 6'd7,
		READER_STATE_8_FAIL = 6'd8,
		RESET_GAME = 6'd9,
		READER_STATE_DRAW_SEQUENCE_ON_SCREEN = 6'd10,
		READER_STATE_WAIT_SEQUENCE_ON_SCREEN = 6'd11,
		READER_STATE_WAIT_SCOREBAR_ON_SCREEN =6'd12,
		READER_STATE_WAIT_CLEAR_SEQUENCE = 6'd13,
		READER_STATE_CLEAR_SEQUENCE = 6'd14,
		READER_STATE_SELECT_DIFFICULTY = 6'd15,
		READER_STATE_DEBOUNCING = 6'd16,
		READER_START_SCOREBAR = 6'd17,
		READER_START_FAIL=6'd18,
		READER_WAIT_PLOTTING_FAIL=6'd19,
		READER_START_STARTPAGE=6'd20,
		READER_WAIT_PLOTTING_STARTPAGE=6'd21,

		READER_LOAD_INITIAL=6'd22,
		READER_WAIT_INITIAL=6'd23,

		READER_LOAD_MIDDLE=6'd24,
		READER_WAIT_MIDDLE=6'd25,

		READER_LOAD_BETWEEN = 6'd26,
		READER_WAIT_BETWEEN = 6'd27,

		READER_LOAD_WIN=6'd28,
		READER_WAIT_WIN=6'd29,
		WAIT_RESET = 6'd30;


/*****************************************************************************
	*                 Internal wires and registers Declarations                 *
	*****************************************************************************/

	// Internal Wires
	reg resetn           ;
	reg enable_next_level;

	wire       ps2_key_pressed;
	wire [7:0] ps2_key_data   ;

	wire       clk                   ;
	wire       timer_done            ;
	wire [7:0] num_char              ;
	reg        ld_difficulty         ;
	reg  [1:0] difficulty            ;
	wire       ready_to_plot_sequence;
	// wire [87:0]sequence;
	// Internal Registers
	reg        finished               ;
	reg        enable_timer           ;
	reg  [1:0] debouncing_count       ;
	reg        failed_input           ;
	reg        correct_sequence       ;
	reg        correct_data_received  ;
	reg        get_next_character     ;
	reg  [7:0] total_keystroke_count  ;
	wire [7:0] comparison_data        ;
	reg  [7:0] last_data_received     ;
	reg  [5:0] current_state          ;
	reg  [5:0] next_state             ;
	reg  [7:0] correct_keystroke_count;
	reg        game_reset             ;
	wire       board_resetn           ;
	reg        clear_sequence         ;
	reg        writeEn                ;
	wire       writeEn_score          ;
	reg  [8:0] x                      ;
	reg  [8:0] y                      ;
	wire [8:0] x_sequence             ;
	wire [8:0] y_sequence             ;
	wire [8:0] x_scorebar             ;
	wire [8:0] y_scorebar             ;
	wire [8:0] x_fail                 ;
	wire [8:0] y_fail                 ;
	wire [5:0] colour_fail            ;
	reg  [5:0] colour                 ;
	wire [5:0] colour_sequence        ;
	wire [5:0] colour_scorebar        ;

	wire [8:0] x_start            ;
	wire [8:0] y_start            ;
	wire [5:0] colour_start       ;
	wire       done_plotting_start;
	reg        writeEn_start      ;


	wire [8:0] x_initial            ;
	wire [8:0] y_initial            ;
	wire [5:0] colour_initial       ;
	wire       done_plotting_initial;
	reg        writeEn_initial      ;



	wire [8:0] x_middle            ;
	wire [8:0] y_middle            ;
	wire [5:0] colour_middle       ;
	wire       done_plotting_middle;
	reg        writeEn_middle      ;
	reg        ld_middle           ;

	wire [8:0] x_between            ;
	wire [8:0] y_between            ;
	wire [5:0] colour_between       ;
	wire       done_plotting_between;
	reg        writeEn_between      ;
	reg        ld_between           ;

	wire [8:0] x_win            ;
	wire [8:0] y_win            ;
	wire [5:0] colour_win       ;
	wire       done_plotting_win;
	reg        writeEn_win      ;
	reg        ld_win           ;

	reg  plot_sequence_output  ;
	reg  plot_scorebar_output  ;
	reg  enable_plot_scorebar  ;
	reg  enable_clear_scorebar ;
	reg  enable_draw_sequence  ;
	wire ready_to_plot_scorebar;
	wire done_plotting_score   ;
	wire writeEn_sequence      ;
	reg  writeEn_fail          ;
	wire done_plotting_fail    ;

/*****************************************************************************
	*                         Finite State Machine(s)                           *
	*****************************************************************************/

	always @(*) begin : state_table
		case (current_state)
			//state that is only active on when reset, to select the difficulty
			READER_STATE_SELECT_DIFFICULTY :
				begin
					next_state = (last_data_received == 8'h16 || last_data_received == 8'h1E || last_data_received == 8'h26) ? READER_LOAD_INITIAL : READER_STATE_SELECT_DIFFICULTY;
				end
			READER_LOAD_INITIAL :
				begin
					next_state = READER_WAIT_INITIAL;
				end
			READER_WAIT_INITIAL :
				begin
					next_state = (done_plotting_initial)?READER_STATE_0_WAIT:READER_WAIT_INITIAL;
				end
			//state to wait for the user to start the game, waits until the user presses <enter> to start
			READER_STATE_0_WAIT                  : next_state = (last_data_received == 8'h5A) ? READER_STATE_DEBOUNCING : READER_STATE_0_WAIT;
			//loads a new level
			READER_STATE_DEBOUNCING              : next_state = (debouncing_count == 0) ?  READER_LOAD_BETWEEN : READER_STATE_DEBOUNCING;
			READER_STATE_1_NEW                   : next_state = READER_STATE_DRAW_SEQUENCE_ON_SCREEN;
			READER_STATE_CLEAR_SEQUENCE          : next_state = READER_STATE_WAIT_CLEAR_SEQUENCE;
			READER_STATE_WAIT_CLEAR_SEQUENCE     : next_state = (ready_to_plot_sequence) ? READER_STATE_DRAW_SEQUENCE_ON_SCREEN : READER_STATE_WAIT_SEQUENCE_ON_SCREEN;
			//sets the registers to start printing a sequence on the screen
			READER_STATE_DRAW_SEQUENCE_ON_SCREEN : next_state = READER_STATE_WAIT_SEQUENCE_ON_SCREEN;
			//waits until the sequence has been printed on the screen
			READER_STATE_WAIT_SEQUENCE_ON_SCREEN : next_state = (ready_to_plot_sequence) ? READER_STATE_2_IDLE : READER_STATE_WAIT_SEQUENCE_ON_SCREEN;
			//waits until the user presses a button to start the timer and reading of the game
			READER_STATE_2_IDLE                  :
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
					next_state = (correct_keystroke_count == num_char) ? READER_START_SCOREBAR : READER_STATE_2_IDLE;
				end
			READER_START_SCOREBAR :
				begin
					next_state = READER_STATE_WAIT_SCOREBAR_ON_SCREEN;
				end
			READER_STATE_WAIT_SCOREBAR_ON_SCREEN :
				begin
					next_state = (done_plotting_score) ? READER_LOAD_MIDDLE : READER_STATE_WAIT_SCOREBAR_ON_SCREEN;
				end
			READER_LOAD_MIDDLE :
				begin
					next_state = READER_WAIT_MIDDLE;
				end
			READER_WAIT_MIDDLE :
				begin
					next_state = (done_plotting_middle) ? READER_STATE_7_OUTPUT :READER_WAIT_MIDDLE;
				end
			READER_LOAD_BETWEEN :
				begin
					next_state = READER_WAIT_BETWEEN;
				end
			READER_WAIT_BETWEEN :
				begin
					next_state = (done_plotting_between) ? READER_STATE_1_NEW :READER_WAIT_BETWEEN;
				end
			READER_LOAD_WIN :
				begin
					next_state = READER_WAIT_WIN;
				end
			READER_WAIT_WIN :
				begin
					next_state = (done_plotting_win) ? WAIT_RESET :READER_WAIT_WIN;
				end

			WAIT_RESET : next_state = (last_data_received == 8'h5A) ? RESET_GAME : WAIT_RESET;
			//if the user has entered a correct sequence then we print out a level screen
			READER_STATE_7_OUTPUT :
				begin
					if (num_char == 8'd12)
						next_state = READER_LOAD_WIN;
					else
						next_state = READER_STATE_0_WAIT;
				end
			//user failed, wait for reset
			READER_STATE_8_FAIL :
				begin
					next_state = READER_START_FAIL;
				end
			RESET_GAME : next_state = READER_START_STARTPAGE;

			READER_START_FAIL :
				begin
					next_state = READER_WAIT_PLOTTING_FAIL;
				end
			READER_WAIT_PLOTTING_FAIL :
				begin
					if(done_plotting_fail) begin
						if(last_data_received==8'h5A)
							next_state = RESET_GAME;
						else
							next_state = READER_WAIT_PLOTTING_FAIL;
					end
					else
						next_state = READER_WAIT_PLOTTING_FAIL;
				end
			READER_START_STARTPAGE :
				begin
					next_state = READER_WAIT_PLOTTING_STARTPAGE;
				end
			READER_WAIT_PLOTTING_STARTPAGE :
				begin
					if(done_plotting_start)
						next_state = READER_STATE_SELECT_DIFFICULTY;
					else
						next_state = READER_WAIT_PLOTTING_STARTPAGE;
				end
			default : next_state = RESET_GAME;
		endcase // current_state
	end

	always @(*) begin : enable_signals
		get_next_character    = 1'b0;
		correct_sequence      = 1'b0;
		correct_data_received = 1'b0;
		failed_input          = 1'b0;
		enable_next_level     = 1'b0;
		finished              = 1'd0;
		enable_draw_sequence  = 1'b0;
		ld_difficulty         = 1'b0;
		game_reset            = 1'b0;
		clear_sequence        = 1'b0;
		plot_sequence_output  = 1'b0;
		plot_scorebar_output  = 1'b0;
		enable_plot_scorebar  = 1'b0;
		writeEn_fail          = 1'b0;
		writeEn_start         = 1'b0;
		writeEn_initial       = 1'b0;
		writeEn_between       = 1'b0;
		writeEn_middle        = 1'b0;
		ld_middle             = 1'b0;
		ld_between            = 1'b0;
		writeEn_win           = 1'b0;
		ld_win                = 1'b0;

		case (current_state)
			READER_STATE_CLEAR_SEQUENCE :
				begin
					clear_sequence = 1'b1;
				end
			READER_STATE_SELECT_DIFFICULTY :
				begin
					ld_difficulty = 1'b1;
				end
			READER_STATE_0_WAIT :
				begin
				end
			READER_STATE_1_NEW :
				begin
					finished          = 1'b1;
					enable_next_level = 1'b1;
				end
			READER_STATE_DRAW_SEQUENCE_ON_SCREEN :
				begin
					finished             = 1'b1;
					enable_draw_sequence = 1'b1;
					plot_sequence_output = 1'b1;
				end
			READER_STATE_WAIT_SEQUENCE_ON_SCREEN :
				begin
					plot_sequence_output = 1'b1;
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
			READER_STATE_6_CHECK :
				begin
					if (correct_keystroke_count == num_char) begin
						plot_scorebar_output = 1'b1;
						enable_plot_scorebar = 1'b1;
					end
				end
			READER_START_SCOREBAR :
				begin
					plot_scorebar_output = 1'b1;
					enable_plot_scorebar = 1'b1;
				end
			READER_STATE_WAIT_SCOREBAR_ON_SCREEN :
				begin
					plot_scorebar_output = 1'b1;
				end
			READER_STATE_7_OUTPUT :
				begin
					correct_sequence = 1'b1;
				end
			READER_STATE_8_FAIL :
				begin
					failed_input = 1'd1;
				end
			RESET_GAME :
				begin
					game_reset = 1'd1;
				end
			READER_START_FAIL :
				begin
					failed_input = 1'd1;
					writeEn_fail = 1'b1;
				end
			READER_WAIT_PLOTTING_FAIL :
				begin
					failed_input = 1'd1;
					writeEn_fail = 1'b1;
				end
			READER_START_STARTPAGE :
				begin
					game_reset    = 1'd1;
					writeEn_start = 1'b1;
				end
			READER_WAIT_PLOTTING_STARTPAGE :
				begin
					game_reset    = 1'd1;
					writeEn_start = 1'b1;
				end
			READER_LOAD_INITIAL :
				begin
					ld_difficulty   = 1'b1;
					writeEn_initial = 1'b1;
				end
			READER_WAIT_INITIAL :
				begin
					ld_difficulty   = 1'b1;
					writeEn_initial = 1'b1;
				end
			READER_WAIT_MIDDLE :
				begin
					ld_middle      = 1'b1;
					writeEn_middle = 1'b1;
				end
			READER_LOAD_MIDDLE :
				begin
					ld_middle      = 1'b1;
					writeEn_middle = 1'b1;
				end
			READER_WAIT_BETWEEN :
				begin
					ld_between      = 1'b1;
					writeEn_between = 1'b1;
				end
			READER_LOAD_BETWEEN :
				begin
					ld_between      = 1'b1;
					writeEn_between = 1'b1;
				end
			READER_WAIT_WIN :
				begin
					ld_win      = 1'b1;
					writeEn_win = 1'b1;
				end
			READER_LOAD_WIN :
				begin
					ld_win      = 1'b1;
					writeEn_win = 1'b1;
				end
		endcase // current_state
	end


	always@(*)begin : plot_passthrough
		if(plot_scorebar_output) begin
			x       = x_scorebar;
			y       = y_scorebar;
			colour  = colour_scorebar;
			writeEn = writeEn_score;
		end
		else if(failed_input) begin
			x       = x_fail;
			y       = y_fail;
			colour  = colour_fail;
			writeEn = writeEn_fail;
		end
		else if(game_reset) begin
			x       = x_start;
			y       = y_start;
			colour  = colour_start;
			writeEn = writeEn_start;
		end
		else if(ld_difficulty)begin
			x       = x_initial;
			y       = y_initial;
			colour  = colour_initial;
			writeEn = writeEn_initial;
		end
		else if(ld_middle) begin
			x       = x_middle;
			y       = y_middle;
			colour  = colour_middle;
			writeEn = writeEn_middle;
		end
		else if(ld_between) begin
			x       = x_between;
			y       = y_between;
			colour  = colour_between;
			writeEn = writeEn_between;
		end
		else if(ld_win) begin
			x       = x_win;
			y       = y_win;
			colour  = colour_win;
			writeEn = writeEn_win;
		end
		else begin
			x       = x_sequence;
			y       = y_sequence;
			colour  = colour_sequence;
			writeEn = writeEn_sequence;
		end

//		x      = (plot_scorebar_output) ? x_scorebar : x_sequence;
//		y      = (plot_scorebar_output) ? y_scorebar : y_sequence;
//		colour = (plot_scorebar_output) ? colour_scorebar : colour_sequence;
//		writeEn = (plot_scorebar_output) ? writeEn_score : writeEn_sequence;
	end
/*****************************************************************************
	*                             Sequential logic                              *
	*****************************************************************************/

	//state changer
	always @ (posedge clk) begin : state_change
		if(!board_resetn) begin
			current_state <= RESET_GAME;
		end
		else begin
			current_state <= next_state;
		end
	end

	//counting the amount of correct keystrokes
	always @(posedge clk) begin
		if(!board_resetn || finished) begin
			correct_keystroke_count <= 0;
		end
		else if (correct_data_received) begin
			//&& debouncing_count == 2'd2
			correct_keystroke_count <= correct_keystroke_count + 1;
		end
	end

	//counting the total amount of keystrokes, included debouncing for 3 enables
	always @(posedge clk) begin
		if (!board_resetn||finished) begin
			debouncing_count      <= 2'd0;
			last_data_received    <= 8'h00;
			total_keystroke_count <= 0;
			enable_timer          <= 0;
		end
		else if (ps2_key_pressed == 1'b1 && debouncing_count == 2'd2) begin
			debouncing_count      <= 0;
			total_keystroke_count <= total_keystroke_count + 1;
		end
		else if (ps2_key_pressed == 1'b1) begin
			last_data_received <= ps2_key_data;
			enable_timer       <= 1;
			debouncing_count   <= debouncing_count + 1'b1;
		end
	end

	//register to read the input and store into a difficulty register
	always@(posedge clk) begin
		if (!board_resetn)
			difficulty <= 0;
		else if(ld_difficulty) begin
			if(last_data_received == 8'h16)
				difficulty <= 1;
			else if (last_data_received == 8'h1E)
				difficulty <= 2;
			else if (last_data_received == 8'h26)
				difficulty <= 3;
		end
	end // always@(posedge clk)

	//always for sending resetn
	//board_resetn is from the DE1-S0C
	//game_reset is from the FSM
	always@(posedge clk)begin
		resetn = 1'd1;
		if(game_reset || !board_resetn)
			resetn = 1'd0;
	end

/*****************************************************************************
	*                            Combinational logic                            *
	*****************************************************************************/
	assign board_resetn = KEY[0];
	assign clk          = CLOCK_50;
	//assign LEDR[1:0]    = difficulty;

/*****************************************************************************
	*                              Internal Modules                             *
	*****************************************************************************/

	wire [95:0] sequence_;

	PS2_Controller PS2 (
		// Inputs
		.CLOCK_50        (clk            ),
		.reset           (!board_resetn  ),
		// Bidirectionals
		.PS2_CLK         (PS2_CLK        ),
		.PS2_DAT         (PS2_DAT        ),
		//Outputs
		.received_data   (ps2_key_data   ),
		.received_data_en(ps2_key_pressed)
	);

	Keyboard_Parser_Modifier i_Keyboard_Parser_Modifier (
		.clk               (clk               ),
		.resetn            (resetn            ),
		.get_next_character(get_next_character),
		.enable_next_level (enable_next_level ),
		.num_char          (num_char          ),
		.sequence_         (sequence_         ),
		.comparison_data   (comparison_data   )
	);

	timer_3s i_timer_3s (
		.clk              (clk              ),
		.q                (timer_done       ),
		.enable_next_level(enable_next_level),
		.enable           (enable_timer     ),
		.num_char         (num_char         ),
		.difficulty       (difficulty       ),
		.resetn           (board_resetn     )
	);

	VGA_sequence_drawing i_VGA_sequence_drawing (
		.clk                   (clk                   ),
		.resetn                (board_resetn          ),
		.num_char              (num_char              ),
		.sequence_             (sequence_             ),
		.x_start               (9'd10                 ),
		.y_start               (9'd198                ),
		.plot_sequence         (enable_draw_sequence  ),
		.clear_sequence        (failed_input          ),
		.writeEn               (writeEn_sequence      ),
		.x                     (x_sequence            ),
		.y                     (y_sequence            ),
		.colour                (colour_sequence       ),
		.ready_to_plot_sequence(ready_to_plot_sequence)
	);

	VGA_score i_VGA_score (
		.clk                   (clk                   ),
		.resetn                (resetn          ),
		.enable_plot_scorebar  (enable_plot_scorebar  ),
		.enable_clear_scorebar (enable_clear_scorebar ),
		.done_plotting         (done_plotting_score   ),
		.x                     (x_scorebar            ),
		.y                     (y_scorebar            ),
		.colour                (colour_scorebar       ),
		.ready_to_plot_scorebar(ready_to_plot_scorebar),
		.writeEn               (writeEn_score         )
	);

	memory_death death (
		.writeEn      (writeEn_fail      ),
		.resetn       (board_resetn      ),
		.clk          (clk               ),
		.x            (x_fail            ),
		.y            (y_fail            ),
		.colour       (colour_fail       ),
		.done_plotting(done_plotting_fail)
	);

	memory_between between (
		.writeEn      (writeEn_between      ),
		.resetn       (board_resetn         ),
		.clk          (clk                  ),
		.x            (x_between            ),
		.y            (y_between            ),
		.colour       (colour_between       ),
		.done_plotting(done_plotting_between)
	);

	memory_start start (
		.writeEn      (writeEn_start      ),
		.resetn       (board_resetn       ),
		.clk          (clk                ),
		.x            (x_start            ),
		.y            (y_start            ),
		.colour       (colour_start       ),
		.done_plotting(done_plotting_start)
	);

	memory_initial initial1 (
		.writeEn      (writeEn_initial      ),
		.resetn       (board_resetn         ),
		.clk          (clk                  ),
		.x            (x_initial            ),
		.y            (y_initial            ),
		.colour       (colour_initial       ),
		.done_plotting(done_plotting_initial)
	);

	memory_middle midd (
		.writeEn      (writeEn_middle      ),
		.resetn       (board_resetn        ),
		.clk          (clk                 ),
		.x            (x_middle            ),
		.y            (y_middle            ),
		.colour       (colour_middle       ),
		.done_plotting(done_plotting_middle)
	);

	memory_win winn (
		.writeEn      (writeEn_win      ),
		.resetn       (board_resetn     ),
		.clk          (clk              ),
		.x            (x_win            ),
		.y            (y_win            ),
		.colour       (colour_win       ),
		.done_plotting(done_plotting_win)
	);

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA (
		.resetn   (board_resetn),
		.clock    (CLOCK_50    ),
		.colour   (colour      ),
		.x        (x           ),
		.y        (y           ),
		.plot     (writeEn     ),
		//Signals for the DAC to drive the monitor.
		.VGA_R    (VGA_R       ),
		.VGA_G    (VGA_G       ),
		.VGA_B    (VGA_B       ),
		.VGA_HS   (VGA_HS      ),
		.VGA_VS   (VGA_VS      ),
		.VGA_BLANK(VGA_BLANK_N ),
		.VGA_SYNC (VGA_SYNC_N  ),
		.VGA_CLK  (VGA_CLK     )
	);

	defparam VGA.RESOLUTION = "320x240";
	defparam VGA.MONOCHROME = "FALSE";
	defparam VGA.BITS_PER_COLOUR_CHANNEL = 2;
	defparam VGA.BACKGROUND_IMAGE = "start.mif";

	hex_decoder i_hex_decoder0 (
		.hex_digit(correct_keystroke_count[3:0]),
		.segments (HEX0                        )
	);

	hex_decoder i_hex_decoder1 (
		.hex_digit(total_keystroke_count[3:0]),
		.segments (HEX2                      )
	);

	hex_decoder i_hex_decoder2 (
		.hex_digit(current_state[3:0]),
		.segments (HEX4              )
	);

	hex_decoder i_hex_decoder3 (
		.hex_digit(current_state[4:4]),
		.segments (HEX5              )
	);

endmodule