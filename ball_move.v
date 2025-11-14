`timescale 1ns / 1ns
module ball_move(
    input wire sys_clk,
    input wire sys_rst_n,
    input wire up,      // 可复用为“开始/重玩”
    input wire down,    // 可选
    input wire left,    // 控制板子左移
    input wire right,   // 控制板子右移
    output wire hsync,
    output wire vsync,
    output wire [15:0] rgb
);
    wire vga_clk;
    wire [9:0] pix_x, pix_y;
    wire [15:0] pix_data;

 pll pll_inst
 (
 .sys_clk(sys_clk),
 .sys_rst_n(sys_rst_n),

 .vga_clk(vga_clk)
 );

 //------------- vga_ctrl_inst -------------
 vga_ctrl vga_ctrl_inst
 (
 .vga_clk (vga_clk ), //VGA working clock, 25MHz
 .sys_rst_n (sys_rst_n ), //Reset signal. Low level is effective
 .pix_data (pix_data ), //color information

 .pix_x (pix_x ), //x coordinate of current pixel
 .pix_y (pix_y ), //y coordinate of current pixel
 .hsync (hsync ), //Line sync signal
 .vsync (vsync ), //Field sync signal
 .rgb (rgb ) //RGB565 color data
 );

    // 新增：游戏核心模块（含 FSM）
    game_core game_inst (
        .vga_clk    (vga_clk),
        .sys_rst_n  (sys_rst_n),
        .pix_x      (pix_x),
        .pix_y      (pix_y),
        .btn_left   (left),
        .btn_right  (right),
        .btn_start  (up),      // 任意键开始
        .pix_data   (pix_data)
    );

    assign rgb = pix_data;
endmodule
