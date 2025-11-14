`timescale 1ns / 1ns

module DevelopmentBoard(
    input wire clk, //50MHz
    input wire reset, B2, B3, B4, B5,
	 // reset is "a"
	 // B2 is "s"
	 // B3 is "d"
	 // B4 is "f"
	 // B5 is "g"
    output wire h_sync, v_sync,
    output wire [15:0] rgb,
	
	output wire led1,
	output wire led2,
	output wire led3,
	output wire led4,
	output wire led5
);

ball_move ball_move_inst
(
	.sys_clk(clk),
	.sys_rst_n(reset),
	.up(B2),
	.down(B3),
	.left(B4),
	.right(B5),
	
	
	.hsync(h_sync),
	.vsync(v_sync),
	.rgb(rgb)
);
    
    assign led1 = reset;             // LED1 indicates reset button press ("a")
    assign led2 = B2;  // LED2 indicates non-COLOR_BAR state (MUST or END)
    assign led3 = B3;  // LED3 indicates END state
    assign led4 = B4;              // Not used
    assign led5 = B5;              // Not used

endmodule
