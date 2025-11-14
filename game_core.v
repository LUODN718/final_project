`timescale 1ns / 1ps
module game_core(
    input  wire        vga_clk,
    input  wire        sys_rst_n,
    input  wire [9:0]  pix_x,
    input  wire [9:0]  pix_y,
    input  wire        btn_left,
    input  wire        btn_right,
    input  wire        btn_start,   // 任意键开始/重玩
    output reg  [15:0] pix_data
);

    // === 参数 ===
    parameter H_VALID = 10'd640;
    parameter V_VALID = 10'd480;
    parameter BLUE    = 16'h001F;
    parameter RED     = 16'hF800;
    parameter GREEN   = 16'h07E0;
    parameter WHITE   = 16'hFFFF;
    parameter PURPLE  = 16'hF81F;

    // === FSM ===
    typedef enum logic [1:0] {STATE_START, STATE_PLAY, STATE_END} state_t;
    state_t state, next_state;

    // === 游戏对象 ===
    reg [9:0] ball_x = 320, ball_y = 100;
    reg  [9:0] ball_dx = 1, ball_dy = 1;  // 方向：1=右/下，0=左/上
    reg [9:0] paddle_x = 280;               // 板子中心 X
    parameter PADDLE_W = 80, PADDLE_H = 10;
    parameter BALL_RADIUS = 10;
    parameter BALL_SPEED = 2;

    wire frame_end = (pix_x == H_VALID-1) && (pix_y == V_VALID-1);

    // === 消抖（简易版，可复用你之前的）===
    reg btn_start_d;
    always @(posedge vga_clk) btn_start_d <= btn_start;
    wire btn_start_press = !btn_start && btn_start_d;  // 上升沿

    // === FSM 状态转移 ===
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) state <= STATE_START;
        else            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_START: if (btn_start_press) next_state = STATE_PLAY;
            STATE_PLAY:  if (ball_y >= V_VALID - BALL_RADIUS) next_state = STATE_END;
            STATE_END:   if (btn_start_press) next_state = STATE_START;
            default:     next_state = STATE_START;
        endcase
    end

    // === 游戏逻辑（仅在 PLAY 状态）===
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            ball_x <= 320; ball_y <= 100;
            ball_dx <= 1; ball_dy <= 1;
            paddle_x <= 280;
        end
        else if (frame_end && state == STATE_PLAY) begin
            // 板子移动
            if (!btn_left  && paddle_x > PADDLE_W/2)        paddle_x <= paddle_x - 3;
            if (!btn_right && paddle_x < H_VALID - PADDLE_W/2 - 1) paddle_x <= paddle_x + 3;

            // 小球移动
            ball_x <= ball_dx ? ball_x + BALL_SPEED : ball_x - BALL_SPEED;
            ball_y <= ball_dy ? ball_y + BALL_SPEED : ball_y - BALL_SPEED;

            // 碰撞检测
            // 左右墙
            if (ball_x <= BALL_RADIUS || ball_x >= H_VALID - 1 - BALL_RADIUS)
                ball_dx <= ~ball_dx;
            // 上墙
            if (ball_y <= BALL_RADIUS)
                ball_dy <= 1;
            // 板子碰撞
            if (ball_y >= V_VALID - PADDLE_H - BALL_RADIUS &&
                ball_y <= V_VALID - PADDLE_H &&
                ball_x >= paddle_x - PADDLE_W/2 &&
                ball_x <= paddle_x + PADDLE_W/2)
                ball_dy <= 0;  // 反弹向上
        end
    end

    // === 绘图逻辑 ===
    always @(*) begin
        pix_data = PURPLE;  // 背景

        case (state)
            STATE_START: begin
                // 简单文字：用矩形拼 "START"
                if (pix_x >= 220 && pix_x <= 420 && pix_y >= 200 && pix_y <= 280)
                    pix_data = WHITE;
            end

            STATE_PLAY: begin
                // 画小球
                if ((pix_x - ball_x)*(pix_x - ball_x) + (pix_y - ball_y)*(pix_y - ball_y) <= BALL_RADIUS*BALL_RADIUS)
                    pix_data = RED;
                // 画板子
                else if (pix_x >= paddle_x - PADDLE_W/2 && pix_x <= paddle_x + PADDLE_W/2 &&
                         pix_y >= V_VALID - PADDLE_H && pix_y <= V_VALID - 1)
                    pix_data = GREEN;
            end

            STATE_END: begin
                // 简单文字：用矩形拼 "END"
                if (pix_x >= 250 && pix_x <= 390 && pix_y >= 200 && pix_y <= 280)
                    pix_data = WHITE;
            end
        endcase
    end

endmodule
