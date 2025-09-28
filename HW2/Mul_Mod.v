module Mul_Mod (
    input  [22:0] A,
    input  [22:0] B,
    output [23:0] Z
);

wire [45:0] U;

Mul_Mod_multiplier mul_mod_inst (
	.A(A),
	.B(B),
	.U(U)
);

wire [34:0] V;

wire [23:0] u_hi;
wire [23:0] u_lo;
assign u_hi = U[45:22];
assign u_lo = U[23:0];

adaptive_adder #(
	.WIDTH(25)
) adder_inst (
	.x({1'b0, u_hi[23:0]}),
	.y({11'b0, u_hi[23:10]}),
	.c_in(1'b0),
	.s(V[34:10]),
	.c_out()
);

assign V[9:0] = u_hi[9:0];
// Finish V

wire [24:0] u_hi_shift_left_1;
wire [25:0] u_hi_shift_left_1_plus_u_hi;
assign u_hi_shift_left_1 = {u_hi[23:0], 1'b0};

adaptive_adder #(
	.WIDTH(26)
) adder_inst2 (
	.x({2'b0, u_hi}),
	.y({1'b0, u_hi_shift_left_1}),
	.c_in(1'b0),
	.s(u_hi_shift_left_1_plus_u_hi),
	.c_out()
);

wire [25:0] u_hi_3_sum;

adaptive_adder #(
	.WIDTH(26)
) adder_inst3 (
	.x({3'b0, u_hi[23:1]}),
	.y(u_hi_shift_left_1_plus_u_hi),
	.c_in(1'b0),
	.s(u_hi_3_sum),
	.c_out()
);

wire [34:0] u_hi_3_sum_plus_V;

adaptive_adder #(
	.WIDTH(35)
) adder_inst4 (
	.x({21'b0, u_hi_3_sum[25:12]}),
	.y(V),
	.c_in(1'b0),
	.s(u_hi_3_sum_plus_V),
	.c_out()
);

wire [23:0] W;
assign W = u_hi_3_sum_plus_V[34:11];
wire W_part_a;
assign W_part_a = W[0];
wire [10:0] W_part_b;
assign W_part_b = W[23:13];
wire [10:0] W_part_c;
assign W_part_c = W[10:0];
wire [12:0] X_part_c;
assign X_part_c = W[12:0]; // W_part_d
wire [10:0] X_part_b;
assign X_part_b = W_part_b - W_part_c; // 11bits
wire X_part_a;
assign X_part_a = W_part_a ^ X_part_b[10];

wire [23:0] X;
assign X = {X_part_a, X_part_b[9:0], X_part_c};
wire [23:0] XY;
assign XY = u_lo - X;
localparam [23:0] Q = 24'd8380417;
wire [23:0] XYQ;
assign XYQ = XY - Q;

// assign Z = W;
assign Z[23:0] = XYQ[23] ? XY : XYQ;

endmodule

module HA(
	input  x,
	input  y,
	output s, 
	output c
);

xor xor1(s,x,y);
and and1(c,x,y);

endmodule

module FA(
	input 	   x,
	input 	   y,
	input 	c_in,
	output     s, 
	output  c_out
);
wire s1, c1, c2;

HA ha0 (.x(x), .y(y), .s(s1), .c(c1));
HA ha1 (.x(s1), .y(c_in), .s(s), .c(c2));
or or1(c_out, c1, c2);

endmodule

module RCA(
	input  [3:0]   x,
	input  [3:0]   y,
	input 		c_in,
	output [3:0]   s,
	output     c_out
);

wire c1, c2, c3;

FA fa0 (.x(x[0]), .y(y[0]), .c_in(c_in), .s(s[0]), .c_out(c1));
FA fa1 (.x(x[1]), .y(y[1]), .c_in(c1), .s(s[1]), .c_out(c2));
FA fa2 (.x(x[2]), .y(y[2]), .c_in(c2), .s(s[2]), .c_out(c3));
FA fa3 (.x(x[3]), .y(y[3]), .c_in(c3), .s(s[3]), .c_out(c_out));

endmodule

module Mul_Mod_multiplier(
	input  [22:0] A,
	input  [22:0] B,
	output [45:0] U
);

	wire [5:0]  b_hi;
	assign b_hi = B[22:17];
	wire [16:0] b_lo;
	assign b_lo = B[16:0];

	wire [28:0] a_mul_b_hi;
	assign a_mul_b_hi = A * b_hi;
	wire [39:0] a_mul_b_lo;
	assign a_mul_b_lo = A * b_lo;

	// wire [45:0] u = {a_mul_b_hi, 17'b0} + {6'b0, a_mul_b_lo};

	adaptive_adder #(
		.WIDTH(46)  // 改為 46
	) adder_inst (
		.x({a_mul_b_hi, 17'b0}),
		.y({6'b0, a_mul_b_lo}),  // 擴展到 46-bit
		.c_in(1'b0),
		.s(U),
		.c_out()
	);

endmodule

module adaptive_adder #(
	parameter WIDTH = 4
)(
	input [WIDTH-1:0] x,
	input  [WIDTH-1:0] y,
	input 	   c_in,
	output [WIDTH-1:0] s,
	output      c_out
);

localparam integer Num_of_RCA = ((WIDTH + 3) >> 2);  // Equal to ceil(WIDTH/4), calculate the number of RCAs needed
localparam integer pad_w = (Num_of_RCA << 2); // For padding the input width to be multiple of 4

wire [pad_w-1:0] s_pad;
wire [Num_of_RCA:0] c; // Carry signals between RCAs

wire [pad_w-1:0] x_pad = {{(pad_w - WIDTH){1'b0}}, x};
wire [pad_w-1:0] y_pad = {{(pad_w - WIDTH){1'b0}}, y};

assign c[0] = c_in;
assign c_out = c[Num_of_RCA];
assign s = s_pad[WIDTH-1:0];

/* Implement a loop to instantiate the required number of RCA modules */

genvar i;
generate
	for (i = 0; i < Num_of_RCA; i = i + 1) begin: rca_gen
		RCA rca_inst (
			.x(x_pad[i*4+3 : i*4]),
			.y(y_pad[i*4+3 : i*4]),
			.c_in(c[i]),
			.s(s_pad[i*4+3 : i*4]),
			.c_out(c[i+1])
		);
	end
endgenerate

endmodule