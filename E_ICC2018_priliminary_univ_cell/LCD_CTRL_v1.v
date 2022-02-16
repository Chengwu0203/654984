module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input clk;
input reset;
input [3:0] cmd;
input cmd_valid;
input [7:0] IROM_Q;
output IROM_rd;
output [5:0] IROM_A;
output IRAM_valid;
output [7:0] IRAM_D;
output [5:0] IRAM_A;
output busy;
output done;

integer i;
//////////////////////////////////////////////////////////////////////
// state
reg [3:0] cs, ns;
parameter [3:0] RST = 4'd0,
                READ = 4'd1,
                PROCESS = 4'd2,
                WRITE = 4'd3,
                DONE = 4'd4,
                SHIFT_UP = 4'd5,
                SHIFT_DOWN = 4'd6,
                SHIFT_LEFT = 4'd7,
                SHIFT_RIGHT = 4'd8,
                MAX = 4'd9,
                MIN = 4'd10,
                AVERAGE = 4'd11,
                COUNTERCLOCKWISE = 4'd12,
                CLOCKWISE = 4'd13,
                MIRROR_X = 4'd14,
                MIRROR_Y = 4'd15;

always @(posedge clk or posedge reset)begin
    if(reset)begin
        cs <= RST;
    end
    else begin
        cs <= ns;
    end
end

always @(*)begin
    case(cs)
        RST:    ns <= READ;
        READ:begin
            if(IROM_A == 6'd63) ns <= PROCESS;
            else                ns <= READ;
        end
        PROCESS:begin
            if(cmd_valid)begin
                case(cmd)
                    4'd0:   ns <= WRITE;
                    4'd1:   ns <= SHIFT_UP;
                    4'd2:   ns <= SHIFT_DOWN;
                    4'd3:   ns <= SHIFT_LEFT;
                    4'd4:   ns <= SHIFT_RIGHT;
                    4'd5:   ns <= MAX;
                    4'd6:   ns <= MIN;
                    4'd7:   ns <= AVERAGE;
                    4'd8:   ns <= COUNTERCLOCKWISE;
                    4'd9:   ns <= CLOCKWISE;
                    4'd10:   ns <= MIRROR_X;
                    4'd11:   ns <= MIRROR_Y;
                endcase
            end
            else begin
                ns <= PROCESS;
            end
        end
        SHIFT_UP:   ns <= PROCESS;
        SHIFT_DOWN:   ns <= PROCESS;
        SHIFT_LEFT:   ns <= PROCESS;
        SHIFT_RIGHT:   ns <= PROCESS;
        MAX:    ns <= PROCESS;
        MIN:    ns <= PROCESS;
        AVERAGE:    ns <= PROCESS;
        COUNTERCLOCKWISE:   ns <= PROCESS;
        CLOCKWISE:  ns <= PROCESS;
        MIRROR_X:   ns <= PROCESS;
        MIRROR_Y:   ns <= PROCESS;
        WRITE:begin
            if(IRAM_A == 6'd63) ns <= DONE;
            else                ns <= WRITE;
        end
        DONE:   ns <= DONE;
        default: ns <= PROCESS;
    endcase
end
//////////////////////////////////////////////////////////////////////
// cnt
reg [2:0] y, x;

always @(posedge clk or posedge reset)begin
    if(reset)begin
        {y, x} <= 6'h0;
    end
    else begin
        if((cs == READ) && (IROM_A == 63))   {y, x} <= {3'h4, 3'h4};
        else if((cs == READ) || (cs == WRITE))   {y ,x} <= {y, x} + 6'h1;
        else if(ns == WRITE)    {y, x} <= 6'h0;
        else begin
            case(cs)
                SHIFT_UP:       {y, x} <= (y == 3'd1) ? {y, x} : {y - 3'h1, x};
                SHIFT_DOWN:     {y, x} <= (y == 3'h7) ? {y, x} : {y + 3'h1, x};
                SHIFT_LEFT:     {y, x} <= (x == 3'h1) ? {y, x} : {y, x - 3'h1};
                SHIFT_RIGHT:    {y, x} <= (x == 3'h7) ? {y, x} : {y, x + 3'h1};
            endcase
        end
    end
end
//////////////////////////////////////////////////////////////////////
// IRAM
reg IRAM_valid;
reg [7:0] IRAM_D;

assign IRAM_A = {y, x};

always @(posedge clk or posedge reset)begin
    if(reset)begin
        IRAM_valid <= 1'd0;
    end
    else begin
        if(ns == WRITE) IRAM_valid <= 1'd1;
        else            IRAM_valid <= 1'd0;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        IRAM_D <= 8'h0;
    end
    else begin
        // if(cs == WRITE) IRAM_D <= image[IRAM_A + 6'h1];
        if((cs != WRITE) && (ns == WRITE))  IRAM_D <= image[0];
        else if(cs == WRITE)                IRAM_D <= image[IRAM_A + 6'h1];
    end
end
//////////////////////////////////////////////////////////////////////
// IROM
reg IROM_rd;
reg [7:0] image [0:63];

assign IROM_A = {y, x};

always @(posedge clk or posedge reset)begin
    if(reset)begin
        IROM_rd <= 1'h0;
    end
    else begin
        if(ns == READ)   IROM_rd <= 1'h1;
        else             IROM_rd <= 1'h0;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        for(i=0;i<64;i=i+1)begin
            image[i] <= 7'h0;
        end
    end
    else begin
        if(IROM_rd)begin
            image[63] <= IROM_Q;
            for(i=0;i<63;i=i+1)begin
                image[i] <= image[i+1];
            end
        end
    end
end
//////////////////////////////////////////////////////////////////////
// cmd

wire [5:0] ref;
assign ref = {y, x};

wire [7:0] max, min;
wire [7:0] tmp1, tmp2, tmp3, tmp4;

// MAX
assign tmp1 = (image[ref] > image[ref - 6'h1]) ? image[ref] : image[ref - 6'h1];
assign tmp2 = (image[ref - 6'h8] > image[ref - 6'h9]) ? image[ref - 6'h8 ] : image[ref - 6'h9];
assign max = (tmp1 > tmp2) ? tmp1 : tmp2;

always @(posedge clk or posedge reset)begin
    if(cs == MAX)begin
        image[ref - 6'h9] <= max;
        image[ref - 6'h8] <= max;
        image[ref - 6'h1] <= max;
        image[ref] <= max;
    end
end

// MIN
assign tmp3 = (image[ref] < image[ref - 6'h1]) ? image[ref] : image[ref - 6'h1];
assign tmp4 = (image[ref - 6'h8] < image[ref - 6'h9]) ? image[ref - 6'h8 ] : image[ref - 6'h9];
assign min = (tmp3 < tmp4) ? tmp3 : tmp4;

always @(posedge clk or posedge reset)begin
    if(cs == MIN)begin
        image[ref - 6'h9] <= min;
        image[ref - 6'h8] <= min;
        image[ref - 6'h1] <= min;
        image[ref] <= min;
    end
end

// AVERAGE
wire [9:0] sum;
wire [7:0] avg;

assign sum = (image[ref] + image[ref - 6'h1]) + (image[ref - 6'h8] + image[ref - 6'h9]);
assign avg = sum >> 2;

always @(posedge clk or posedge reset)begin
    if(cs == AVERAGE)begin
        image[ref - 6'h9] <= avg;
        image[ref - 6'h8] <= avg;
        image[ref - 6'h1] <= avg;
        image[ref] <= avg;
    end
end

// COUNTERCLOCKWISE
always @(posedge clk or posedge reset)begin
    if(cs == COUNTERCLOCKWISE)begin
        image[ref - 6'h9] <= image[ref - 6'h8];
        image[ref - 6'h8] <= image[ref];
        image[ref - 6'h1] <= image[ref - 6'h9];
        image[ref] <= image[ref - 6'h1];
    end
end

// CLOCKWISE
always @(posedge clk or posedge reset)begin
    if(cs == CLOCKWISE)begin
        image[ref - 6'h9] <= image[ref - 6'h1];
        image[ref - 6'h8] <= image[ref - 6'h9];
        image[ref - 6'h1] <= image[ref];
        image[ref] <= image[ref - 6'h8];
    end
end

// MIRROR_Y
always @(posedge clk or posedge reset)begin
    if(cs == MIRROR_Y)begin
        image[ref - 6'h9] <= image[ref - 6'h8];
        image[ref - 6'h8] <= image[ref - 6'h9];
        image[ref - 6'h1] <= image[ref];
        image[ref] <= image[ref - 6'h1];
    end
end

// MIRROR_X
always @(posedge clk or posedge reset)begin
    if(cs == MIRROR_X)begin
        image[ref - 6'h9] <= image[ref - 6'h1];
        image[ref - 6'h8] <= image[ref];
        image[ref - 6'h1] <= image[ref - 6'h9];
        image[ref] <= image[ref - 6'h8];
    end
end
//////////////////////////////////////////////////////////////////////
// control
reg busy, done;

always @(posedge clk or posedge reset)begin
    if(reset)begin
        busy <= 1'h1;
    end
    else begin
        if((ns == PROCESS) || (ns == DONE)) busy <= 1'h0;
        else    busy <= 1'h1;
    end
end

always @(posedge clk or posedge reset)begin
    if(reset)begin
        done <= 1'd0;
    end
    else begin
        if(ns == DONE)  done <= 1'd1;
        else            done <= 1'd0;
    end
end
//////////////////////////////////////////////////////////////////////
endmodule
