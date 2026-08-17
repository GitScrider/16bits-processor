// =============================================================================
//  hex7seg.sv  --  hexadecimal digit to 7-segment decoder for the DE2-115
// -----------------------------------------------------------------------------
//  The DE2-115 HEX displays are ACTIVE-LOW: a '0' on a segment turns it ON.
//  Bit mapping (Terasic convention):  seg[6:0] = { g, f, e, d, c, b, a }
//      seg[0]=a  seg[1]=b  seg[2]=c  seg[3]=d  seg[4]=e  seg[5]=f  seg[6]=g
// =============================================================================

module hex7seg (
    input  logic [3:0] digit,
    output logic [6:0] seg   // active-low, {g,f,e,d,c,b,a}
);
    always_comb begin
        unique case (digit)
            //                    gfedcba
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111; // all off
        endcase
    end
endmodule
