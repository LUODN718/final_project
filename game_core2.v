`timescale 1ns / 1ps
module game_core(
    input wire vga_clk,          // VGA 时钟：25.175 MHz
    input wire sys_rst_n,        // 系统复位（低电平有效）
    input wire [9:0] pix_x,      // 当前像素 X 坐标 (0~639)
    input wire [9:0] pix_y,      // 当前像素 Y 坐标 (0~479)
    input wire btn_left,         // 左移按钮（低电平有效）
    input wire btn_right,        // 右移按钮（低电平有效）
    input wire btn_start,        // 开始/重玩按钮（低电平有效）
    output reg [15:0] pix_data   // 输出像素颜色 (RGB565)
);

    // === VGA 参数 ===
    parameter H_VALID = 10'd640;
    parameter V_VALID = 10'd480;

    // === 颜色定义 (RGB565) ===
    localparam RED   = 16'hF800;   // 小球用
    localparam BLACK = 16'h0000;   // 木板和文字用
    localparam WHITE  = 16'hFFFF;   // 背景 + 文字

    // === 游戏参数 ===
    localparam PADDLE_W = 80;
    localparam PADDLE_H = 10;
    localparam BALL_RADIUS = 10;
    localparam BALL_SPEED =12;
    localparam PADDLE_SPEED = 10;

    // === 帧结束信号 ===
    wire frame_end = (pix_x == H_VALID-1) && (pix_y == V_VALID-1);

    // === 按键消抖（上升沿检测）===
    reg btn_start_d, btn_left_d, btn_right_d;
    always @(posedge vga_clk) begin
        btn_start_d <= btn_start;
        btn_left_d  <= btn_left;
        btn_right_d <= btn_right;
    end
    wire btn_start_press = !btn_start && btn_start_d;
    wire btn_left_press  = !btn_left  && btn_left_d;
    wire btn_right_press = !btn_right && btn_right_d;

    // === FSM 状态机 ===
    typedef enum logic [1:0] {STATE_START, STATE_PLAY, STATE_END} state_t;
    state_t state, next_state;

    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) state <= STATE_START;
        else            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_START: if (btn_start_press) next_state = STATE_PLAY;
            STATE_PLAY:  if (ball_y_next >= V_VALID - BALL_RADIUS) next_state = STATE_END;
            STATE_END:   if (btn_start_press) next_state = STATE_START;
            default:     next_state = STATE_START;
        endcase
    end

    // === 游戏对象寄存器 ===
    reg [9:0] ball_x = 320, ball_y = 100;
    reg ball_dx = 1; // 1=右, 0=左
    reg ball_dy = 1; // 1=下, 0=上
    reg [9:0] paddle_x = 280;

    // === 预测下一帧位置与方向 ===
    reg [9:0] ball_x_next, ball_y_next;
    reg ball_dx_next, ball_dy_next;

    always @(*) begin
        ball_x_next = ball_dx ? ball_x + BALL_SPEED : ball_x - BALL_SPEED;
        ball_y_next = ball_dy ? ball_y + BALL_SPEED : ball_y - BALL_SPEED;
        ball_dx_next = ball_dx;
        ball_dy_next = ball_dy;

        // 左右墙碰撞
        if (ball_x_next <= BALL_RADIUS || ball_x_next >= H_VALID - 1 - BALL_RADIUS)
            ball_dx_next = ~ball_dx_next;
        // 上墙碰撞
        if (ball_y_next <= BALL_RADIUS)
            ball_dy_next = 1'b1;

        // 木板碰撞检测（带宽容区间）
        if (ball_y_next + BALL_RADIUS >= V_VALID - PADDLE_H &&
            ball_y_next - BALL_RADIUS <= V_VALID - PADDLE_H + BALL_SPEED + 2 &&
            ball_x_next >= paddle_x - PADDLE_W/2 &&
            ball_x_next < = paddle_x + PADDLE_W/2)
        begin
            ball_dy_next = 1'b0; // 向上反弹
            // 根据击中位置改变水平方向
            if (ball_x_next < paddle_x - PADDLE_W/6)
                ball_dx_next = 1'b0;
            else if (ball_x_next > paddle_x + PADDLE_W/6)
                ball_dx_next = 1'b1;
        end
    end

    // === 游戏逻辑更新（每帧末尾）===
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            ball_x <= 320;
            ball_y <= 100;
            ball_dx <= 1;
            ball_dy <= 1;
            paddle_x <= 280;
        end
        else if (frame_end && state == STATE_PLAY) begin
                   // 木板移动 —— 按住连续移动 + 使用 PADDLE_SPEED 参数
        if (!btn_left && paddle_x > PADDLE_W/2)
            paddle_x <= paddle_x - PADDLE_SPEED;
        if (!btn_right && paddle_x < H_VALID - PADDLE_W/2 - 1)
            paddle_x <= paddle_x + PADDLE_SPEED;

            // 小球位置更新
            ball_x <= ball_x_next;
            ball_y <= ball_y_next;
            ball_dx <= ball_dx_next;
            ball_dy <= ball_dy_next;

            // 防卡死
            if (ball_y > V_VALID - PADDLE_H - BALL_RADIUS)
                ball_y <= V_VALID - PADDLE_H - BALL_RADIUS - 1;
        end
    end

    // === 绘图逻辑 ===
    always @(*) begin
        pix_data = WHITE;  // 修改1：背景改为白色

        case (state)
                                                   STATE_START: begin
                pix_data = WHITE; // 背景白色

                // ==================== START 粗体版（再左移5像素，绝对正中！）====================
                
                // ------ S ------
                if (pix_x >= 185 && pix_x < 235 && pix_y >= 200 && pix_y < 280) begin
                    if (
                        (pix_y >= 200 && pix_y < 218) ||
                        (pix_y >= 218 && pix_y < 240 && pix_x >= 185 && pix_x < 203) ||
                        (pix_y >= 238 && pix_y < 252) ||
                        (pix_y >= 252 && pix_y < 274 && pix_x >= 217 && pix_x < 235) ||
                        (pix_y >= 262 && pix_y < 280)
                    )
                        pix_data = BLACK;
                end

                // ------ T ------
                else if (pix_x >= 245 && pix_x < 295 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 || (pix_x >= 267 && pix_x < 277))  // 中竖10px粗，更大气
                        pix_data = BLACK;
                end

                // ------ A ------
                else if (pix_x >= 305 && pix_x < 355 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 ||
                        (pix_y >= 238 && pix_y < 248) ||
                        pix_x < 320 ||
                        pix_x >= 340)
                        pix_data = BLACK;
                end

                // ------ R ------
                else if (pix_x >= 365 && pix_x < 415 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_x < 383 ||                                              // 左竖
                        pix_y < 218 ||                                              // 顶横
                        (pix_y >= 238 && pix_y < 248) ||                            // 中横
                        (pix_y >= 218 && pix_y < 240 && pix_x >= 397) ||            // 右上圆弧
                        (pix_y >= 240 && pix_y < 248 && pix_x >= 400) ||            // 圆弧过渡
                        (pix_y >= 248 && pix_y < 280 && pix_x >= 397 && pix_x <= 397 + (pix_y - 248))) // 完美斜腿
                        pix_data = BLACK;
                end

                // ------ T (第二个) ------
                else if (pix_x >= 425 && pix_x < 475 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 || (pix_x >= 447 && pix_x < 457))  
                        pix_data = BLACK;
                end
            end
            STATE_PLAY: begin
                // 小球
                if ((pix_x - ball_x)*(pix_x - ball_x) + (pix_y - ball_y)*(pix_y - ball_y) <= BALL_RADIUS*BALL_RADIUS)
                    pix_data = RED;  
                // 木板
                else if (pix_x >= paddle_x - PADDLE_W/2 && pix_x <= paddle_x + PADDLE_W/2 &&
                         pix_y >= V_VALID - PADDLE_H && pix_y <= V_VALID - 1)
                    pix_data = BLACK;
            end
                STATE_END: begin
                pix_data = WHITE; // 背景

                // ------ E ------  
                if (pix_x >= 230 && pix_x < 280 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 ||                                      // 顶横
                        (pix_y >= 235 && pix_y < 245) ||                    // 中横
                        pix_y >= 262 ||                                     // 底横
                        pix_x < 248)                                        // 左竖
                        pix_data = BLACK;
                end

                // ------ N ------ 
                else if (pix_x >= 300 && pix_x < 350 && pix_y >= 200 && pix_y < 280) begin
                    if (
                        (pix_x >= 300 && pix_x < 313) ||                                      // 左竖
                        (pix_x >= 337 && pix_x < 350) ||                                      // 右竖
                        (pix_y >= 200 + ((pix_x - 300) * 43 / 25) && 
                         pix_y < 212 + ((pix_x - 300) * 43 / 25))                             // 斜杠
                    )
                        pix_data = BLACK;
                end

                // ------ D ------  
                else if (pix_x >= 370 && pix_x < 420 && pix_y >= 200 && pix_y < 280) begin
                    if (
                        pix_x < 388 ||                                              // 左竖
                        (pix_y >= 200 && pix_y < 218) ||                            // 顶横
                        (pix_y >= 262 && pix_y < 280) ||                            // 底横
                        (pix_x >= 402 && pix_x < 420 && (                          
                            (pix_y >= 218 && pix_y < 238) || 
                            (pix_y >= 238 && pix_y < 262) || 
                            (pix_y >= 262 && pix_y < 280 && pix_x < 415)
                        ))
                    )
                        pix_data = BLACK;
                end
            end
        endcase
    end

endmodule
