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
or (c_out, c1, c2);

endmodule

