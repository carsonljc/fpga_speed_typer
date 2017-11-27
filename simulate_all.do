vlib work_modelsim

vlog Keyboard_Reader.v
vlog Keyboard_Parser_Modifier.v
vlog timer_3s.v
vlog VGA_sequence_drawing.v
	vlog VGA_character_drawing.v
	vlog datapath_sequence.v
	vlog control_sequence.v
	vlog control_draw.v
	vlog datapath_draw.v

vsim Keyboard_Reader
log {/*}
add wave {/*}
