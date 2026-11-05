// Portable 128-bit line memory for RTL functional testing. Each request has
// three rising edges of latency; two turnaround edges let CHIP register ready.
module slow_memory(
    input logic clk, mem_read, mem_write,
    input logic [27:0] mem_addr,
    input logic [127:0] mem_wdata,
    output logic [127:0] mem_rdata,
    output logic mem_ready
);
    logic [31:0] mem[0:4095];
    logic [27:0] address;
    logic [127:0] write_data;
    bit writing;
    int delay_edges, turnaround;

    always @(posedge clk) begin
        mem_ready <= 0;
        if (turnaround > 0) turnaround <= turnaround - 1;
        else if (delay_edges > 0) begin
            delay_edges <= delay_edges - 1;
            if (delay_edges == 1) begin
                if (address >= 1024) $fatal(1, "Address outside slow memory");
                for (int word=0; word<4; word++)
                    if (writing) mem[address*4+word] <= write_data[32*word+:32];
                    else mem_rdata[32*word+:32] <= mem[address*4+word];
                mem_ready <= 1;
                turnaround <= 2;
            end
        end else if (mem_read || mem_write) begin
            address <= mem_addr;
            write_data <= mem_wdata;
            writing <= mem_write;
            delay_edges <= 3;
        end
    end
endmodule
