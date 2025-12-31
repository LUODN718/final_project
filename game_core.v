`timescale 1ns/1ps
module game_core (
    input wire vga_clk, // 25.175 MHz
    input wire sys_rst_n,
    input wire [9:0] pix_x,
    input wire [9:0] pix_y,
    input wire btn_left,
    input wire btn_right,
    input wire btn_start,
    output reg [15:0] pix_data
);

    parameter H_VALID = 10'd640;
    parameter V_VALID = 10'd480;

    localparam RED = 16'hF800;
    localparam BLACK = 16'h0000;
    localparam WHITE = 16'hFFFF;
    localparam GREEN = 16'h07E0;
    
    localparam PADDLE_W = 80;
    localparam PADDLE_H = 10;
    localparam BALL_RADIUS = 10;
    localparam BALL_SPEED = 15;
    localparam PADDLE_SPEED = 25;
    
    localparam BRICK_W = 60;
    localparam BRICK_H = 20;
    localparam BRICK_COLS = 8;
    localparam BRICK_ROWS = 5;
    localparam BRICK_START_X = 40;
    localparam BRICK_START_Y = 150;
    localparam BRICK_GAP = 4;
   
    wire frame_end = (pix_x == H_VALID-1) && (pix_y == V_VALID-1);
   
    reg btn_start_d, btn_left_d, btn_right_d;
    always @(posedge vga_clk) begin
        btn_start_d <= btn_start;
        btn_left_d <= btn_left;
        btn_right_d <= btn_right;
    end
    wire btn_start_press = !btn_start && btn_start_d;
    wire btn_left_press = !btn_left && btn_left_d;
    wire btn_right_press = !btn_right && btn_right_d;
   
    typedef enum logic [2:0] {
        STATE_START,
        STATE_PLAY,
        STATE_END,
        STATE_WIN
    } state_t;
    state_t state, next_state;
    always @(posedge vga_clk or negedge sys_rst_n)
        if (!sys_rst_n) state <= STATE_START;
        else state <= next_state;
    always @(*) begin
        next_state = state;
        case (state)
            STATE_START: if (btn_start_press) next_state = STATE_PLAY;
            STATE_PLAY: if (ball_y_next >= V_VALID - BALL_RADIUS)
                            next_state = STATE_END;
                        else if (bricks_all_clear)
                            next_state = STATE_WIN;
            STATE_END,
            STATE_WIN: if (btn_start_press) next_state = STATE_PLAY; 
            default: next_state = STATE_START;
        endcase
    end
   
    reg [9:0] ball_x = 320, ball_y = 100;
    reg ball_dx = 1; // 1=右 0=左
    reg ball_dy = 1; // 1=下 0=上
    reg [9:0] paddle_x = 280;
   
    reg [BRICK_COLS*BRICK_ROWS-1:0] brick_alive;
    wire bricks_all_clear = (brick_alive == {BRICK_COLS*BRICK_ROWS{1'b0}});
    
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            brick_alive <= {BRICK_COLS*BRICK_ROWS{1'b1}};
        else if ((state == STATE_START && btn_start_press) ||
                 (state == STATE_END && btn_start_press) ||
                 (state == STATE_WIN && btn_start_press))
            brick_alive <= {BRICK_COLS*BRICK_ROWS{1'b1}};
    end
    
     reg [9:0] ball_x_next, ball_y_next;
    reg ball_dx_next, ball_dy_next;
    reg hit_brick_this_frame;
    reg [7:0] brick_to_destroy = 8'd255;
    always @(*) begin
        
        ball_x_next = ball_dx ? ball_x + BALL_SPEED : ball_x - BALL_SPEED;
        ball_y_next = ball_dy ? ball_y + BALL_SPEED : ball_y - BALL_SPEED;
        ball_dx_next = ball_dx;
        ball_dy_next = ball_dy;
        hit_brick_this_frame = 0;
        brick_to_destroy = 8'd255;
       
        if (ball_x_next <= BALL_RADIUS || ball_x_next >= H_VALID - 1 - BALL_RADIUS)
            ball_dx_next = ~ball_dx_next;
        
        if (ball_y_next <= BALL_RADIUS)
            ball_dy_next = 1'b1;
        
        if (ball_y_next + BALL_RADIUS >= V_VALID - PADDLE_H &&
            ball_y_next - BALL_RADIUS <= V_VALID - PADDLE_H + BALL_SPEED + 2 &&
            ball_x_next >= paddle_x - PADDLE_W/2 &&
            ball_x_next <= paddle_x + PADDLE_W/2)
        begin
            ball_dy_next = 1'b0; 
            if (ball_x_next < paddle_x - PADDLE_W/6) ball_dx_next = 1'b0;
            else if (ball_x_next > paddle_x + PADDLE_W/6) ball_dx_next = 1'b1;
        end
      
        if (state == STATE_PLAY && !hit_brick_this_frame) begin
            integer i, j;
            for (j = 0; j < BRICK_ROWS; j = j + 1) begin
                for (i = 0; i < BRICK_COLS; i = i + 1) begin
                    if (brick_alive[j*BRICK_COLS + i]) begin
                        reg [9:0] bx0 = BRICK_START_X + i*(BRICK_W + BRICK_GAP);
                        reg [9:0] bx1 = bx0 + BRICK_W - 1;
                        reg [9:0] by0 = BRICK_START_Y + j*(BRICK_H + BRICK_GAP);
                        reg [9:0] by1 = by0 + BRICK_H - 1;
                        if (ball_x_next + BALL_RADIUS >= bx0 &&
                            ball_x_next - BALL_RADIUS <= bx1 &&
                            ball_y_next + BALL_RADIUS >= by0 &&
                            ball_y_next - BALL_RADIUS <= by1)
                        begin
                            brick_to_destroy = j*BRICK_COLS + i;
                            ball_dy_next = 1'b1;
                            if (ball_x_next < bx0 - 5) ball_dx_next = 1'b1;
                            else if (ball_x_next > bx1 + 5) ball_dx_next = 1'b0;
                            hit_brick_this_frame = 1;
                        end
                    end
                end
            end
        end
    end
   
    always @(posedge vga_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            ball_x <= 320; ball_y <= 100;
            ball_dx <= 1; ball_dy <= 1;
            paddle_x <= 280;
        end
        else if (frame_end) begin
            if (state == STATE_PLAY) begin
if (!btn_left || !btn_right) begin
     reg [9:0] paddle_x_candidate = paddle_x;
     if (!btn_left)
         paddle_x_candidate = paddle_x - PADDLE_SPEED;
     else if (!btn_right)
         paddle_x_candidate = paddle_x + PADDLE_SPEED;

     if (paddle_x_candidate < PADDLE_W/2)
         paddle_x <= PADDLE_W/2;
     else if (paddle_x_candidate > H_VALID - 1 - PADDLE_W/2)
         paddle_x <= H_VALID - 1 - PADDLE_W/2;
     else
         paddle_x <= paddle_x_candidate;
end
              
                ball_x <= ball_x_next;
                ball_y <= ball_y_next;
                ball_dx <= ball_dx_next;
                ball_dy <= ball_dy_next;
               
                if (brick_to_destroy < BRICK_COLS*BRICK_ROWS)
                    brick_alive[brick_to_destroy] <= 1'b0;
               
                if (ball_y > V_VALID - PADDLE_H - BALL_RADIUS)
                    ball_y <= V_VALID - PADDLE_H - BALL_RADIUS - 1;
            end
           
            if ((state == STATE_END || state == STATE_WIN) && next_state == STATE_PLAY) begin
                ball_x <= 320; ball_y <= 100;
                ball_dx <= 1; ball_dy <= 1;
                paddle_x <= 280;
            end
        end
    end
   
    always @(*) begin
        pix_data = WHITE;
        
        if (state == STATE_PLAY || state == STATE_WIN) begin
            integer i, j;
            for (j = 0; j < BRICK_ROWS; j = j + 1) begin
                for (i = 0; i < BRICK_COLS; i = i + 1) begin
                    if (brick_alive[j*BRICK_COLS + i]) begin
                        reg [9:0] bx0 = BRICK_START_X + i*(BRICK_W + BRICK_GAP);
                        reg [9:0] bx1 = bx0 + BRICK_W - 1;
                        reg [9:0] by0 = BRICK_START_Y + j*(BRICK_H + BRICK_GAP);
                        reg [9:0] by1 = by0 + BRICK_H - 1;
                        if (pix_x >= bx0 && pix_x <= bx1 && pix_y >= by0 && pix_y <= by1)
                            pix_data = GREEN;
                    end
                end
            end
        end
       
        if (state == STATE_PLAY || state == STATE_WIN)
            if ((pix_x - ball_x)*(pix_x - ball_x) + (pix_y - ball_y)*(pix_y - ball_y) <= BALL_RADIUS*BALL_RADIUS)
                pix_data = RED;
        
        if (state == STATE_PLAY || state == STATE_WIN)
            if (pix_x >= paddle_x - PADDLE_W/2 && pix_x <= paddle_x + PADDLE_W/2 &&
                pix_y >= V_VALID - PADDLE_H && pix_y <= V_VALID-1)
                pix_data = BLACK;
       
        case (state)
            STATE_START: begin
                pix_data = WHITE;
                // ------ S ------
                if (pix_x >= 185 && pix_x < 235 && pix_y >= 200 && pix_y < 280) begin
                    if ((pix_y >= 200 && pix_y < 218) ||
                        (pix_y >= 218 && pix_y < 240 && pix_x >= 185 && pix_x < 203) ||
                        (pix_y >= 238 && pix_y < 252) ||
                        (pix_y >= 252 && pix_y < 274 && pix_x >= 217 && pix_x < 235) ||
                        (pix_y >= 262 && pix_y < 280))
                        pix_data = BLACK;
                end
                // ------ T ------
                else if (pix_x >= 245 && pix_x < 295 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 || (pix_x >= 267 && pix_x < 277))
                        pix_data = BLACK;
                end
                // ------ A ------
                else if (pix_x >= 305 && pix_x < 355 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 || (pix_y >= 238 && pix_y < 248) || pix_x < 320 || pix_x >= 340)
                        pix_data = BLACK;
                end
                // ------ R ------
                else if (pix_x >= 365 && pix_x < 415 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_x < 383 ||
                        pix_y < 218 ||
                        (pix_y >= 238 && pix_y < 248) ||
                        (pix_y >= 218 && pix_y < 240 && pix_x >= 397) ||
                        (pix_y >= 240 && pix_y < 248 && pix_x >= 400) ||
                        (pix_y >= 248 && pix_y < 280 && pix_x >= 397 && pix_x <= 397 + (pix_y - 248)))
                        pix_data = BLACK;
                end
                // ------ T ------
                else if (pix_x >= 425 && pix_x < 475 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 || (pix_x >= 447 && pix_x < 457))
                        pix_data = BLACK;
                end
            end
            STATE_END:
            begin
                pix_data = WHITE;
                // ------ E ------
                if (pix_x >= 230 && pix_x < 280 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_y < 218 || (pix_y >= 235 && pix_y < 245) || pix_y >= 262 || pix_x < 248)
                        pix_data = BLACK;
                end
                // ------ N ------
                else if (pix_x >= 300 && pix_x < 360 && pix_y >= 200 && pix_y < 280) begin
                    if ((pix_x >= 300 && pix_x < 320) ||
                        (pix_x >= 340 && pix_x < 360) ||
                        (pix_x >= 320 && pix_x < 340 &&
                         pix_y >= 200 + (pix_x-320)*60/20 &&
                         pix_y < 224 + (pix_x-320)*60/20))
                        pix_data = BLACK;
                end
                // ------ D ------
                else if (pix_x >= 375 && pix_x < 425 && pix_y >= 200 && pix_y < 280) begin
                    if (pix_x < 393 ||
                        (pix_y >= 200 && pix_y < 218) ||
                        (pix_y >= 262 && pix_y < 280) ||
                        (pix_x >= 407 && pix_x < 425 &&
                         ((pix_y >= 218 && pix_y < 238) ||
                          (pix_y >= 238 && pix_y < 262) ||
                          (pix_y >= 262 && pix_y < 280 && pix_x < 420))))
                        pix_data = BLACK;
                end
            end
            STATE_WIN: begin 
                pix_data = WHITE;
                // ------ W ------
                if (pix_x >= 205 && pix_x < 265 && pix_y >= 200 && pix_y < 280) begin
                    if ((pix_x >= 205 && pix_x < 220 && pix_y >= 200 + (pix_x-205)*4 && pix_y < 200 + (pix_x-205)*4 + 50) ||
                        (pix_x >= 220 && pix_x < 235 && pix_y >= 260 - (pix_x-220)*4 && pix_y < 260 - (pix_x-220)*4 + 39) ||
                        (pix_x >= 235 && pix_x < 250 && pix_y >= 200 + (pix_x-235)*4 && pix_y < 224 + (pix_x-235)*4 + 35) ||
                        (pix_x >= 250 && pix_x < 265 && pix_y >= 260 - (pix_x-250)*60/14 && pix_y < 275 - (pix_x-250)*60/14 + 30))
                        pix_data = BLACK;
                end
                // ------ I ------
                else if (pix_x >= 280 && pix_x < 340 && pix_y >= 200 && pix_y < 280) begin
                    if ((pix_y >= 200 && pix_y < 218) || (pix_y >= 262 && pix_y < 280) || (pix_x >= 303 && pix_x < 318))
                        pix_data = BLACK;
                end
                // ------ N ------
                else if (pix_x >= 355 && pix_x < 415 && pix_y >= 200 && pix_y < 280) begin
                    if ((pix_x >= 355 && pix_x < 375) ||
                        (pix_x >= 395 && pix_x < 415) ||
                        (pix_x >= 375 && pix_x < 395 &&
                         pix_y >= 200 + (pix_x-375)*60/20 &&
                         pix_y < 224 + (pix_x-375)*60/20))
                        pix_data = BLACK;
                end
            end
        endcase
    end
endmodule
