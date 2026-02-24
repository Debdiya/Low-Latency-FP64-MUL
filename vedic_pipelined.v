`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 01:02:43 AM
// Design Name: 
// Module Name: vedic_pipelined
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module vedic_13x13 (
    input  wire [12:0] a,
    input  wire [12:0] b,
    output wire [25:0] y
);
    // Direct multiplication - synthesizer will optimize
    assign y = a * b;
endmodule

