`timescale 1ns / 1ps//可弹球版本
module game_core(
    input wire vga_clk,      // VGA 时钟：25.175 MHz
    input wire sys_rst_n,    // 系统复位（低电平有效）
    input wire [9:0] pix_x,  // 当前像素 X 坐标 (0~639)
    input wire [9:0] pix_y,  // 当前像素 Y 坐标 (0~479)
    input wire btn_left,     // 左移按钮（低电平有效）
    input wire btn_right,    // 右移按钮（低电平有效）
    input wire btn_start,    // 开始/重玩按钮（低电平有效）
    output reg [15:0] pix_data // 输出像素颜色 (RGB565)
);

    // === VGA 参数 ===
    parameter H_VALID = 10'd640;
    parameter V_VALID = 10'd480;

    // === 颜色定义 (RGB565) ===
    localparam BLUE   = 16'h001F;  // 背景
    localparam RED    = 16'hF800;  // 小球
    localparam GREEN  = 16'h07E0;  // 木板
    localparam WHITE  = 16'hFFFF;  // 文字
    localparam PURPLE = 16'hF81F;  // 背景（紫色）

    // === 游戏参数 ===
    localparam PADDLE_W = 80;
    localparam PADDLE_H = 10;
    localparam BALL_RADIUS = 10;
    localparam BALL_SPEED  = 2;
    localparam PADDLE_SPEED = 3;

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
    reg       ball_dx = 1;   // 1=右, 0=左
    reg       ball_dy = 1;   // 1=下, 0=上
    reg [9:0] paddle_x = 280;

    // === 预测下一帧位置与方向（关键！）===
    reg [9:0] ball_x_next, ball_y_next;
    reg       ball_dx_next, ball_dy_next;

    always @(*) begin
        // 默认下一位置
        ball_x_next = ball_dx ? ball_x + BALL_SPEED : ball_x - BALL_SPEED;
        ball_y_next = ball_dy ? ball_y + BALL_SPEED : ball_y - BALL_SPEED;
        ball_dx_next = ball_dx;
        ball_dy_next = ball_dy;

        // === 1. 左右墙碰撞 ===
        if (ball_x_next <= BALL_RADIUS || ball_x_next >= H_VALID - 1 - BALL_RADIUS)
            ball_dx_next = ~ball_dx_next;

        // === 2. 上墙碰撞 ===
        if (ball_y_next <= BALL_RADIUS)
            ball_dy_next = 1'b1;

        // === 3. 木板碰撞（预测 + 宽容区间）===
        // 木板顶部 Y = V_VALID - PADDLE_H
        // 小球底部进入木板区域：ball_y_next + BALL_RADIUS >= 木板顶部
         // 宽容区间：防止速度过快跳过
        if (ball_y_next + BALL_RADIUS >= V_VALID - PADDLE_H &&
            ball_y_next - BALL_RADIUS <= V_VALID - PADDLE_H + BALL_SPEED + 2 &&
            ball_x_next >= paddle_x - PADDLE_W/2 &&
            ball_x_next <= paddle_x + PADDLE_W/2)
        begin
            ball_dy_next = 1'b0;  // 反弹向上

            // === 反弹角度（根据击中位置）===
            // 左1/3 → 向左飞，中间保持，右1/3 → 向右飞
            if (ball_x_next < paddle_x - PADDLE_W/6)
                ball_dx_next = 1'b0;
            else if (ball_x_next > paddle_x + PADDLE_W/6)
                ball_dx_next = 1'b1;
            // 中间保持原方向
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
            // 木板移动
            if (btn_left_press && paddle_x > PADDLE_W/2)
                paddle_x <= paddle_x - PADDLE_SPEED;
            if (btn_right_press && paddle_x < H_VALID - PADDLE_W/2 - 1)
                paddle_x <= paddle_x + PADDLE_SPEED;

            // 小球更新（使用预测值）
            ball_x <= ball_x_next;
            ball_y <= ball_y_next;
            ball_dx <= ball_dx_next;
            ball_dy <= ball_dy_next;

            // 防卡死：如果小球陷入木板，强制推上去
            if (ball_y > V_VALID - PADDLE_H - BALL_RADIUS)
                ball_y <= V_VALID - PADDLE_H - BALL_RADIUS - 1;
        end
    end

    // === 绘图逻辑 ===
    always @(*) begin
        pix_data = PURPLE; // 默认背景

        case (state)
            STATE_START: begin
                // 简单 "START" 文字（用矩形拼）
                if ((pix_x >= 220 && pix_x <= 420) && (pix_y >= 200 && pix_y <= 280))
                    pix_data = WHITE;
            end

            STATE_PLAY: begin
                // 画小球（圆形）
                if ((pix_x - ball_x)*(pix_x - ball_x) + (pix_y - ball_y)*(pix_y - ball_y) <= BALL_RADIUS*BALL_RADIUS)
                    pix_data = RED;

                // 画木板
                else if (pix_x >= paddle_x - PADDLE_W/2 && pix_x <= paddle_x + PADDLE_W/2 &&
                         pix_y >= V_VALID - PADDLE_H && pix_y <= V_VALID - 1)
                    pix_data = GREEN;
            end

            STATE_END: begin
                // 简单 "GAME OVER" 文字
                if ((pix_x >= 200 && pix_x <= 440) && (pix_y >= 200 && pix_y <= 280))
                    pix_data = WHITE;
            end
        endcase
    end

endmodule
