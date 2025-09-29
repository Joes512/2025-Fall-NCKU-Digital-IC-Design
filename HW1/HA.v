module HA(
	input  x,
	input  y,
	output s, 
	output c
);

xor xor1(s,x,y);
and and1(c,x,y);

endmodule