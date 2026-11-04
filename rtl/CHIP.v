// Top module of your design, you cannot modify this module!!
module CHIP (	clk,
				rst_n,
//----------for slow_memD------------
				mem_read_D,
				mem_write_D,
				mem_addr_D,
				mem_wdata_D,
				mem_rdata_D,
				mem_ready_D,
//----------for slow_memI------------
				mem_read_I,
				mem_write_I,
				mem_addr_I,
				mem_wdata_I,
				mem_rdata_I,
				mem_ready_I,
//----------for TestBed--------------				
				DCACHE_addr, 
				DCACHE_wdata,
				DCACHE_wen,
				PC   
			);
input			clk, rst_n;
//--------------------------

output			mem_read_D;
output			mem_write_D;
output	[31:4]	mem_addr_D;
output	[127:0]	mem_wdata_D;
input	[127:0]	mem_rdata_D;
input			mem_ready_D;
//--------------------------
output			mem_read_I;
output			mem_write_I;
output	[31:4]	mem_addr_I;
output	[127:0]	mem_wdata_I;
input	[127:0]	mem_rdata_I;
input			mem_ready_I;
//----------for TestBed--------------
output	[29:0]	DCACHE_addr;
output	[31:0]	DCACHE_wdata;
output			DCACHE_wen;
output	[31:0]	PC;
//--------------------------

// wire declaration
wire        ICACHE_ren;
wire        ICACHE_wen;
wire [30:0] ICACHE_addr;
wire [31:0] ICACHE_wdata;
wire        ICACHE_stall;
wire [31:0] ICACHE_rdata;

wire        DCACHE_ren;
wire        DCACHE_wen;
wire [29:0] DCACHE_addr;
wire [31:0] DCACHE_wdata;
wire        DCACHE_stall;
wire [31:0] DCACHE_rdata;
wire [31:0] PC;

//my wires
wire compressed;

// input blocking
reg rst, m_ready_I, m_ready_D;
reg [127:0] m_rdata_I, m_rdata_D;

// always @(*) begin
// 	rst = rst_n;
// end

always @(posedge clk) begin
	rst <= rst_n;
	m_ready_I <= mem_ready_I;
	m_ready_D <= mem_ready_D;
	m_rdata_I <= mem_rdata_I;
	m_rdata_D <= mem_rdata_D;
end

//=========================================
	// Note that the overall design of your RISCV includes:
	// 1. pipelined RISCV processor
	// 2. data cache
	// 3. instruction cache


	RISCV_Pipeline i_RISCV(
		// control interface
		.clk            (clk)           , 
		.rst_n          (rst)         ,
//----------I cache interface-------		
		.ICACHE_ren     (ICACHE_ren)    ,
		.ICACHE_wen     (ICACHE_wen)    ,
		.ICACHE_addr    (ICACHE_addr)   ,
		.ICACHE_wdata   (ICACHE_wdata)  ,
		.ICACHE_stall   (ICACHE_stall)  ,
		.ICACHE_rdata   (ICACHE_rdata)  ,
		.compressed(compressed),
//----------D cache interface-------
		.DCACHE_ren     (DCACHE_ren)    ,
		.DCACHE_wen     (DCACHE_wen)    ,
		.DCACHE_addr    (DCACHE_addr)   ,
		.DCACHE_wdata   (DCACHE_wdata)  ,
		.DCACHE_stall   (DCACHE_stall)  ,
		.DCACHE_rdata   (DCACHE_rdata)	,
//--------------PC-----------------
		.PC(PC)
	);
	

	cache_2way D_cache(
        .clk        (clk)         ,
        .proc_reset (~rst)      ,
        .proc_read  (DCACHE_ren)  ,
        .proc_write (DCACHE_wen)  ,
        .proc_addr  (DCACHE_addr) ,
        .proc_rdata (DCACHE_rdata),
        .proc_wdata (DCACHE_wdata),
        .proc_stall (DCACHE_stall),
        .mem_read   (mem_read_D)  ,
        .mem_write  (mem_write_D) ,
        .mem_addr   (mem_addr_D)  ,
        .mem_wdata  (mem_wdata_D) ,
        .mem_rdata  (m_rdata_D) ,
        .mem_ready  (m_ready_D)
	);

	i_cache I_cache(
        .clk        (clk)         ,
        .proc_reset (~rst)      ,
        .proc_read  (ICACHE_ren)  ,
        .proc_write (ICACHE_wen)  ,
        .proc_addr  (ICACHE_addr) ,
        .proc_rdata (ICACHE_rdata),
        .proc_wdata (ICACHE_wdata),
        .proc_stall (ICACHE_stall),
        .mem_read   (mem_read_I)  ,
        .mem_write  (mem_write_I) ,
        .mem_addr   (mem_addr_I)  ,
        .mem_wdata  (mem_wdata_I) ,
        .mem_rdata  (m_rdata_I) ,
        .mem_ready  (m_ready_I) ,
		.compressed (compressed)
	);
endmodule



//==================== PROCESSOR ========================

module RISCV_Pipeline(
	// control interface
			clk           , 
			rst_n         ,
	//----------I cache interface-------		
			ICACHE_ren    ,
			ICACHE_wen    ,
			ICACHE_addr   ,
			ICACHE_wdata  ,
			ICACHE_stall  ,
			ICACHE_rdata  ,
	//----------D cache interface-------
			DCACHE_ren    ,
			DCACHE_wen    ,
			DCACHE_addr   ,
			DCACHE_wdata  ,
			DCACHE_stall  ,
			DCACHE_rdata  ,
	//--------------PC-----------------
			PC,
			compressed
	);

//-------- input decleration ---------
input clk, rst_n;

// instruction cache
input [31:0] ICACHE_rdata;
input ICACHE_stall;

// data memory cache
input [31:0] DCACHE_rdata;
input DCACHE_stall;

input compressed;

//-------- output decleration --------

output [31:0] PC;

// instruction cache
output ICACHE_ren; // ideally should be constant 1 to continuously read (might need to load_stall)
output ICACHE_wen; // should be constant 0 since never writing to instructin cache
output [30:0] ICACHE_addr;
output [31:0] ICACHE_wdata;  // should be constant 0 since never writing to instructin cache

// data memory cache
output DCACHE_ren;
output DCACHE_wen;
output [29:0] DCACHE_addr;
output [31:0] DCACHE_wdata;


// register declaration
reg [31:0] PC_r, PC_w; //Program Counter
reg [31:0] alu_input;
reg [31:0] branch_jalr_reg1, branch_reg2; //registers for branch instructions
reg [3:0] alu_control; //alu needs to do a total of 14 different instructions
reg load_stall; //stall signals for load-use hazzard
reg pipe12_flush, pipe23_flush;


// wire declaration
wire reg_write; //reg file control
wire mem_write, mem_read; // data memory control
wire branch, jal, jalr; // pc control
wire mem_to_reg, alu_src ;// data delect control
wire [1:0] alu_op; // alu control
wire branch_misspredict, IF_jal, IF_branch;
wire mul_stall; //stall signals for load and mul instructions



wire[31:0] reg_data_1, reg_data_2;
wire[31:0] alu_output;


// -------- pipeline registers -------------
	//-----IF/ID: pipe12--------
	reg[31:0] pipe12_instruction_w,		 pipe12_instruction_r; // store instruction fetched to be decoded
	reg[31:0] pipe12_PC_w,				 pipe12_PC_r; // store PC incase BEQ needs it later
	wire      pipe12_BP_w;
	reg		  pipe12_BP_r; // store branch prediction
	reg	      branch_result; // branch prediction result
	reg		  compressed12_w, compressed12_r;

	//-----ID/EX: pipe23--------
	reg[2:0]  pipe23_func3_w,			 pipe23_func3_r;
	reg[1:0]  pipe23_func7_w,			 pipe23_func7_r;
	reg[31:0] pipe23_immediate_w,		 pipe23_immediate_r; 
	reg[31:0] pipe23_reg_data_1_w,		 pipe23_reg_data_1_r;
	reg[31:0] pipe23_reg_data_2_w,		 pipe23_reg_data_2_r;
	reg[4:0]  pipe23_write_number_w,	 pipe23_write_number_r;
	reg[31:0] pipe23_nextPC_w,			 pipe23_nextPC_r; // store PC incase BEQ needs it later
	reg[31:0] pipe23_PC_w,				 pipe23_PC_r; // store PC incase BEQ needs it later
	reg		  pipe23_BP_w,               pipe23_BP_r;
	reg[4:0]  pipe23_reg1_w,			 pipe23_reg1_r;
	reg[4:0]  pipe23_reg2_w,			 pipe23_reg2_r;
    reg       pipe23_instruction12_w,     pipe23_instruction12_r;
		// control signal for alu
	reg 	  pipe23_alu_src_w, 		 pipe23_alu_src_r;
	reg[1:0]  pipe23_alu_op_w, 			 pipe23_alu_op_r;
		// control signal for memory
	reg 	  pipe23_mem_write_w, 		 pipe23_mem_write_r;
	reg 	  pipe23_mem_read_w, 		 pipe23_mem_read_r;
		// control signal for writeback
	reg 	  pipe23_mem_to_reg_w, 		 pipe23_mem_to_reg_r;
	reg 	  pipe23_reg_write_w, 		 pipe23_reg_write_r;

		// PC controls should be taken care of as soon as possible
	reg 	  pipe23_branch_w, 			 pipe23_branch_r;
	reg 	  pipe23_jal_w, 			 pipe23_jal_r; 
	reg 	  pipe23_jalr_w, 			 pipe23_jalr_r; 

	//------- EX/MEM: pipe34 ----------
	reg[31:0] pipe34_alu_output_w, 		 pipe34_alu_output_r;
	reg[31:0] pipe34_reg_data_2_w, 		 pipe34_reg_data_2_r; // store register 2 data for writing to memory
	reg[4:0]  pipe34_write_number_w, 	 pipe34_write_number_r;
	reg[31:0] pipe34_nextPC_w,				 pipe34_nextPC_r;
		// control signal for memory
	reg 	  pipe34_mem_write_w, 		 pipe34_mem_write_r;
	reg 	  pipe34_mem_read_w, 		 pipe34_mem_read_r;
		// control signal for writeback
	reg 	  pipe34_mem_to_reg_w, 		 pipe34_mem_to_reg_r;
	reg 	  pipe34_reg_write_w, 		 pipe34_reg_write_r;

		// PC controls should be taken care of as soon as possible
	reg 	  pipe34_branch_w, 			 pipe34_branch_r;
	reg 	  pipe34_jal_w, 			 pipe34_jal_r; 
	reg 	  pipe34_jalr_w, 			 pipe34_jalr_r; 
	

	//------- MEM/WB: pipe45 ------------
	reg[31:0] pipe45_reg_write_data_w, 	 pipe45_reg_write_data_r;
	reg[4:0]  pipe45_write_number_w, 	 pipe45_write_number_r;
		// control signal for writeback
	reg 	  pipe45_mem_to_reg_w, 		 pipe45_mem_to_reg_r;
	reg 	  pipe45_reg_write_w, 		 pipe45_reg_write_r;


// ---------- output assignment -------------
	assign PC = PC_r;

	// for instruction cache
	assign ICACHE_ren = 1;//!(jalr||pipe23_jalr_r);
	assign ICACHE_addr = PC_r[31:1]; //fetch instruction from cache, byte offset bits 1-0
	assign ICACHE_wen = 0;
	assign ICACHE_wdata = 31'b0;

	// for data memory cache
	assign DCACHE_wen = pipe34_mem_write_r; // control signal for writing to data memory
	assign DCACHE_ren = pipe34_mem_read_r;
	assign DCACHE_wdata = {pipe34_reg_data_2_r[7:0],pipe34_reg_data_2_r[15:8],pipe34_reg_data_2_r[23:16],pipe34_reg_data_2_r[31:24]}; //data writeen to data memory comes from reg_data_2
	assign DCACHE_addr = pipe34_alu_output_r[31:2]; // address for read/write of data memory comes from alu result


	
//--------------- IF: stage 1 ----------------//
	// BP_nBitHistory_mBitPC_correlation #(.n(3), .m(2)) BP(
	// 	.clk(clk),
	// 	.rst_n(rst_n),
	// 	.branch(branch),
	// 	.cpu_stall(ICACHE_stall||DCACHE_stall||mul_stall||load_stall),
	// 	.branch_result(branch_result),
	// 	.IF_PC(pipe12_PC_w),
	// 	.ID_PC(pipe12_PC_r),
	// 	.branch_predict(pipe12_BP_w)
	// );

	// BP_nbit_2level #(.n(3)) BP(
	// 	.clk(clk),
	// 	.rst_n(rst_n),
	// 	.branch(branch),
	// 	.cpu_stall(ICACHE_stall||DCACHE_stall||mul_stall||load_stall),
	// 	.branch_result(branch_result),
	// 	.branch_predict(pipe12_BP_w)
	// );

	// BP_Saturation BP(
	// 	.clk(clk),
	// 	.rst_n(rst_n),
	// 	.branch(pipe23_branch_r),
	// 	.cpu_stall(ICACHE_stall||DCACHE_stall||mul_stall||load_stall),
	// 	.branch_result(branch_result),
	// 	.branch_predict(pipe12_BP_w)
	// );


	assign pipe12_BP_w = 1'b0;

	assign branch_misspredict = (pipe23_branch_r && !pipe23_instruction12_r && ((branch_jalr_reg1 == branch_reg2) != pipe23_BP_r)) || (pipe23_branch_r &&  pipe23_instruction12_r && ((branch_jalr_reg1 != branch_reg2) != pipe23_BP_r));
	assign IF_jal = pipe12_instruction_w[6:0] == 7'b1101111;
	assign IF_branch = (pipe12_instruction_w[6:0] == 7'b1100011) && pipe12_BP_w;

	always @(*) begin
		//endian converter
		pipe12_instruction_w = ICACHE_rdata; //{ICACHE_rdata[7:0],ICACHE_rdata[15:8],ICACHE_rdata[23:16],ICACHE_rdata[31:24]};
		pipe12_PC_w = PC_r;
		PC_w = PC_r + 4;
		branch_result = pipe23_BP_r;
		pipe12_flush = 0;
		pipe23_flush = 0;

		case({pipe23_jalr_r, branch_misspredict, jal})
			3'b100, 3'b101: begin //jalr
				PC_w = branch_jalr_reg1 + pipe23_immediate_r;

				//flush
				pipe12_flush = 1;
				pipe23_flush = 1;
			end
			3'b010, 3'b011: begin //branch misprediction
				if(pipe23_BP_r)begin //branch actually not taken
					PC_w = pipe23_nextPC_r;
				end else begin //branch actually taken
					PC_w = pipe23_PC_r + pipe23_immediate_r;
				end
				branch_result = !pipe23_BP_r;

				//flush
				pipe12_flush = 1;
				pipe23_flush = 1;
		
			end
			4'b001: begin //jal
				PC_w = $signed(pipe12_PC_r) + $signed(pipe23_immediate_w);
				pipe12_flush = 1;
			end
			default: begin
				if(compressed) begin
					PC_w = PC_r + 2;
				end else begin
					PC_w = PC_r + 4;
				end
			end
		endcase
		
		compressed12_w = compressed;
		
	end
	

//------------- ID: stage 2 ------------------//
	//immediate generation (combinational)
	always @(*) begin
		case(pipe12_instruction_r[6:0])
		7'b1100011: begin //BEQ
			pipe23_immediate_w = $signed({pipe12_instruction_r[31],pipe12_instruction_r[7],pipe12_instruction_r[30:25],pipe12_instruction_r[11:8],1'b0});
		end
		7'b1101111: begin //JAL
			pipe23_immediate_w = $signed({pipe12_instruction_r[31],pipe12_instruction_r[19:12],pipe12_instruction_r[20],pipe12_instruction_r[30:21],1'b0});
		end
		7'b1100111: begin //JALR
			pipe23_immediate_w = $signed(pipe12_instruction_r[31:20]);
		end        
		7'b0000011: begin //LW
			pipe23_immediate_w = $signed(pipe12_instruction_r[31:20]);
		end
		7'b0100011: begin //SW
			pipe23_immediate_w = $signed({pipe12_instruction_r[31:25],pipe12_instruction_r[11:7]});
		end
		7'b0010011: begin //ITYPE
			pipe23_immediate_w = $signed({pipe12_instruction_r[31:20]});
		end
		default:
			pipe23_immediate_w = 0;
		endcase
	end


	// Control (combinational)
	Control control(
		.instruction(pipe12_instruction_r[6:0]),
		.write_enable(reg_write),
		.mem_write(mem_write),
		.mem_read(mem_read),
		.branch(branch),
		.jal(jal),
		.jalr(jalr),
		.mem_to_reg(mem_to_reg),
		.alu_src(alu_src),
		.alu_op(alu_op)
	);

	//reg file 
	Reg_file reg_file(
		.clk(clk),
		.rst_n(rst_n),
		.read_1(pipe12_instruction_r[19:15]), //index of registers to be read
		.read_2(pipe12_instruction_r[24:20]), 
		.write_number(pipe45_write_number_r), // index of register to be written ==> should come from MEM_WB pipeline
		.write_enable(pipe45_reg_write_r), // RegWrite signal from Control
		.write_data(pipe45_reg_write_data_r), // number to be written
		.read_data_1(reg_data_1), // data read from registers
		.read_data_2(reg_data_2)
	);  

	// store register data and control logic
	always @(*) begin
		pipe23_func3_w = pipe12_instruction_r[14:12];
		pipe23_func7_w = {pipe12_instruction_r[30],pipe12_instruction_r[25]};
		
		pipe23_reg_data_1_w = reg_data_1;
		pipe23_reg_data_2_w = reg_data_2;
		//data hazard detection for register writing
		if(pipe23_reg_write_r && (|pipe23_write_number_r) && (pipe23_write_number_r == pipe12_instruction_r[19:15])) begin
			pipe23_reg_data_1_w = alu_output;

		end else if(pipe34_reg_write_r && (|pipe34_write_number_r) && (pipe34_write_number_r == pipe12_instruction_r[19:15])) begin
			pipe23_reg_data_1_w = pipe45_reg_write_data_w;

		end else begin
			pipe23_reg_data_1_w = reg_data_1;
		end

		if(pipe23_reg_write_r && (|pipe23_write_number_r) &&(pipe23_write_number_r == pipe12_instruction_r[24:20]))begin
			pipe23_reg_data_2_w = alu_output;
		end else if(pipe34_reg_write_r && (|pipe34_write_number_r) && (pipe34_write_number_r == pipe12_instruction_r[24:20]))begin
			//data hazard for loading
			
			pipe23_reg_data_2_w = pipe45_reg_write_data_w;
		end else begin
			pipe23_reg_data_2_w = reg_data_2;
		end


		
		
		pipe23_write_number_w = pipe12_instruction_r[11:7];
		pipe23_nextPC_w = (compressed12_r)? pipe12_PC_r+2 : pipe12_PC_r+4;

		pipe23_alu_op_w = alu_op;
		pipe23_alu_src_w = alu_src;
		pipe23_branch_w = branch;
		pipe23_jal_w = jal;
		pipe23_jalr_w = jalr;

		pipe23_mem_write_w = mem_write;
		pipe23_mem_read_w = mem_read;

		pipe23_reg_write_w = reg_write;
		pipe23_mem_to_reg_w = mem_to_reg;

		pipe23_BP_w = pipe12_BP_r;
		pipe23_PC_w = pipe12_PC_r;

		pipe23_reg1_w = pipe12_instruction_r[19:15];
		pipe23_reg2_w = pipe12_instruction_r[24:20];

		pipe23_instruction12_w = pipe12_instruction_r[12];


		//default no load_stall
		load_stall = 0;

		//load hazard
		if(pipe23_mem_read_r && (|pipe23_write_number_r) && ((pipe23_write_number_r == pipe12_instruction_r[19:15]) || (pipe23_write_number_r == pipe12_instruction_r[24:20]))) begin // detect load
			//load_stall for one cycle
			load_stall = 1;

			// insert NOP
			pipe23_func3_w = 0;
			pipe23_func7_w = 0;

		
			pipe23_reg_data_1_w = 0;
			pipe23_reg_data_2_w = 0;
			pipe23_write_number_w = 0;
			pipe23_nextPC_w = 0;

			pipe23_alu_op_w = 0;
			pipe23_alu_src_w = 0;
			pipe23_branch_w = 0;
			pipe23_jal_w = 0;
			pipe23_jalr_w = 0;

			pipe23_mem_write_w = 0;
			pipe23_mem_read_w = 0;

			pipe23_reg_write_w = 0;
			pipe23_mem_to_reg_w = 0;

		end else begin
			load_stall = 0;
		end


		
	end

//------------- EX: stage 3 ------------------//

	
	always @(*) begin // selector for alu input
		if(pipe23_alu_src_r)begin
			alu_input = pipe23_immediate_r;
		end else begin
			alu_input = pipe23_reg_data_2_r;
		end


	end

	//ALU control // needs to be optimized
	always @(*) begin
		alu_control = 0;
		case ({pipe23_alu_op_r,pipe23_func3_r})
			5'b00010: begin //load or store jal jalr
				alu_control = 1; //add
			end
			5'b10000, 5'b10001: begin //branch 
				alu_control = 2;
			end
			5'b01000: begin //add or sub or mul
				case(pipe23_func7_r)
					2'b00: alu_control = 1; //add
					2'b10: alu_control = 2; //sub
					2'b01: alu_control = 10; //mul
					default: alu_control = 0;
				endcase
			end
			5'b01010: begin //slt
				alu_control = 3;
			end
			5'b01100: begin //xor
				alu_control = 6;
			end
			5'b01110: begin //or
				alu_control = 5;
			end
			5'b01111: begin //and
				alu_control = 4;
			end
			5'b00100: begin //addi
				alu_control = 1;
			end
			5'b11000: begin //addi
				alu_control = 1;
			end
			5'b11010: begin //slti
				alu_control = 3;
			end
			5'b11100: begin //xori
				alu_control = 6;
			end
			5'b11110: begin //ori
				alu_control = 5;
			end
			5'b11111: begin //andi
				alu_control = 4;
			end
			5'b11101: begin //srli srai
				if(pipe23_func7_r[1]) begin
					alu_control = 8;
				end else begin
					alu_control = 9;
				end	
			end
			5'b11001: begin //slli
				alu_control = 7;
			end
			
			default: begin
				alu_control = 0;
			end
		endcase
	end
	

	// ALU
	ALU alu(
		.clk(clk),
		.rst_n(rst_n),
		.data_1(pipe23_reg_data_1_r),
		.data_2(alu_input), 
		.ctrl(alu_control), // ALU opcode
		.alu_output(alu_output),
		.cpu_stall(ICACHE_stall || DCACHE_stall),
		.mul_stall(mul_stall)
	);

	// store alu output
	always @(*) begin
		pipe34_alu_output_w = alu_output;
		pipe34_reg_data_2_w = pipe23_reg_data_2_r;
		pipe34_write_number_w = pipe23_write_number_r;

		pipe34_jal_w = pipe23_jal_r;
		pipe34_jalr_w = pipe23_jalr_r;
		pipe34_branch_w = pipe23_branch_r;

		pipe34_mem_read_w = pipe23_mem_read_r;
		pipe34_mem_write_w = pipe23_mem_write_r;

		pipe34_mem_to_reg_w = pipe23_mem_to_reg_r;
		pipe34_reg_write_w = pipe23_reg_write_r;
		pipe34_nextPC_w = pipe23_nextPC_r;


		// branch and jalr data hazard forwarding
		branch_jalr_reg1 = pipe23_reg_data_1_r;
		branch_reg2 = pipe23_reg_data_2_r;

		// forwarding to EX for branch and jalr
		if(pipe34_reg_write_r && (|pipe34_write_number_r) && (pipe34_write_number_r == pipe23_reg1_r)) begin
			branch_jalr_reg1 = (pipe34_jal_r || pipe34_jalr_r)? pipe34_nextPC_r : pipe34_alu_output_r;
		end else if(pipe45_reg_write_r && (|pipe45_write_number_r) && (pipe45_write_number_r == pipe23_reg1_r))begin
			branch_jalr_reg1 = pipe45_reg_write_data_r;
		end else begin
			branch_jalr_reg1 = pipe23_reg_data_1_r;
		end

		if(pipe34_reg_write_r && (|pipe34_write_number_r) && (pipe34_write_number_r == pipe23_reg2_r)) begin
			branch_reg2 = (pipe34_jal_r || pipe34_jalr_r)? pipe34_nextPC_r : pipe34_alu_output_r;
		end else if(pipe45_reg_write_r && (|pipe45_write_number_r) && (pipe45_write_number_r == pipe23_reg2_r))begin
			branch_reg2 = pipe45_reg_write_data_r;
		end else begin
			branch_reg2 = pipe23_reg_data_2_r;
		end

	end

// ------------ MEM: stage 4 --------------//

	// store memory output
	always @(*) begin
		// start data selection early
		if(pipe34_jal_r | pipe34_jalr_r) begin
			pipe45_reg_write_data_w = pipe34_nextPC_r;
		end else if(pipe34_mem_to_reg_r) begin
			pipe45_reg_write_data_w = {DCACHE_rdata[7:0],DCACHE_rdata[15:8],DCACHE_rdata[23:16],DCACHE_rdata[31:24]};
		end else begin
			pipe45_reg_write_data_w = pipe34_alu_output_r;
		end
		
		pipe45_write_number_w = pipe34_write_number_r;
		pipe45_reg_write_w = pipe34_reg_write_r;
	end

// ------------- WB: stage 5 --------------//


//Sequential Ciruit
always @(posedge clk) begin //synchronous reset
    if(!rst_n) begin

        PC_r <= 0;
		pipe12_instruction_r <= 0;
		pipe12_PC_r <= 0;
		pipe12_BP_r <= 0;

		pipe23_alu_op_r <= 0;
		pipe23_alu_src_r <= 0;
		pipe23_branch_r <= 0;
		pipe23_func3_r <= 0;
		pipe23_func7_r <= 0;
		pipe23_immediate_r <= 0;
		pipe23_jal_r <= 0;
		pipe23_mem_read_r <= 0;
		pipe23_jalr_r <= 0;
		pipe23_mem_to_reg_r <= 0;
		pipe23_mem_write_r <= 0;
		pipe23_nextPC_r <= 0;
		pipe23_reg_data_1_r <= 0;
		pipe23_reg_data_2_r <= 0;
		pipe23_reg_write_r <= 0;
		pipe23_write_number_r <= 0;

		pipe34_alu_output_r <= 0;
		pipe34_branch_r <= 0;
		pipe34_jal_r <= 0;
		pipe34_jalr_r <= 0;
		pipe34_mem_read_r <= 0;
		pipe34_mem_write_r <= 0;
		pipe34_reg_data_2_r <= 0;
		pipe34_reg_write_r <= 0;
		pipe34_write_number_r <= 0;

		pipe45_mem_to_reg_r <= 0;
		pipe45_reg_write_data_r <= 0;
		pipe45_reg_write_r <= 0;
		pipe45_write_number_r <= 0;

		compressed12_r <= 0;
    end else if((!DCACHE_stall) && !(ICACHE_stall) && !(mul_stall))begin
		if(!load_stall) begin
			PC_r <= PC_w;

			if(pipe12_flush) begin
				pipe12_instruction_r <= 0;
				pipe12_PC_r <= 0;
				pipe12_BP_r <= 0;
				compressed12_r <= 0;
			end else begin
				pipe12_instruction_r <= pipe12_instruction_w;
				pipe12_PC_r <= pipe12_PC_w;
				pipe12_BP_r <= pipe12_BP_w;
				compressed12_r <= compressed12_w;
			end

		end else begin
			PC_r <= PC_r;
			pipe12_instruction_r <= pipe12_instruction_r;
			pipe12_PC_r <= pipe12_PC_r;
			pipe12_BP_r <= pipe12_BP_r;
			compressed12_r <= compressed12_r;
		end

		if(pipe23_flush) begin
			pipe23_alu_op_r <= 0;
			pipe23_alu_src_r <= 0;
			pipe23_branch_r <= 0;
			pipe23_func3_r <= 0;
			pipe23_func7_r <= 0;
			pipe23_immediate_r <= 0;
			pipe23_jal_r <= 0;
			pipe23_mem_read_r <= 0;
			pipe23_jalr_r <= 0;
			pipe23_mem_to_reg_r <= 0;
			pipe23_mem_write_r <= 0;
			pipe23_nextPC_r <= 0;
			pipe23_reg_data_1_r <= 0;
			pipe23_reg_data_2_r <= 0;
			pipe23_reg_write_r <= 0;
			pipe23_write_number_r <= 0;
			pipe23_BP_r <= 0;
			pipe23_PC_r <= 0;
			pipe23_reg1_r <= 0;
			pipe23_reg2_r <= 0;
			pipe23_instruction12_r <= 0;
		end else begin
			pipe23_alu_op_r <= pipe23_alu_op_w;
			pipe23_alu_src_r <= pipe23_alu_src_w;
			pipe23_branch_r <= pipe23_branch_w;
			pipe23_func3_r <= pipe23_func3_w;
			pipe23_func7_r <= pipe23_func7_w;
			pipe23_immediate_r <= pipe23_immediate_w;
			pipe23_jal_r <= pipe23_jal_w;
			pipe23_mem_read_r <= pipe23_mem_read_w;
			pipe23_jalr_r <= pipe23_jalr_w;
			pipe23_mem_to_reg_r <= pipe23_mem_to_reg_w;
			pipe23_mem_write_r <= pipe23_mem_write_w;
			pipe23_nextPC_r <= pipe23_nextPC_w;
			pipe23_reg_data_1_r <= pipe23_reg_data_1_w;
			pipe23_reg_data_2_r <= pipe23_reg_data_2_w;
			pipe23_reg_write_r <= pipe23_reg_write_w;
			pipe23_write_number_r <= pipe23_write_number_w;
			pipe23_BP_r <= pipe23_BP_w;
			pipe23_PC_r <= pipe23_PC_w;
			pipe23_reg1_r <= pipe23_reg1_w;
			pipe23_reg2_r <= pipe23_reg2_w;
			pipe23_instruction12_r <= pipe23_instruction12_w;
		end
		pipe34_alu_output_r <= pipe34_alu_output_w;
		pipe34_branch_r <= pipe34_branch_w;
		pipe34_jal_r <= pipe34_jal_w;
		pipe34_jalr_r <= pipe34_jalr_w;
		pipe34_mem_read_r <= pipe34_mem_read_w;
		pipe34_mem_write_r <= pipe34_mem_write_w;
		pipe34_reg_data_2_r <= pipe34_reg_data_2_w;
		pipe34_reg_write_r <= pipe34_reg_write_w;
		pipe34_write_number_r <= pipe34_write_number_w;
		pipe34_mem_to_reg_r <= pipe34_mem_to_reg_w;
		pipe34_nextPC_r <= pipe34_nextPC_w;

		pipe45_mem_to_reg_r <= pipe45_mem_to_reg_w;
		pipe45_reg_write_data_r <= pipe45_reg_write_data_w;
		pipe45_reg_write_r <= pipe45_reg_write_w;
		pipe45_write_number_r <= pipe45_write_number_w;
	end else begin

		PC_r <= PC_r;
		pipe12_instruction_r <= pipe12_instruction_r;
		pipe12_PC_r <= pipe12_PC_r;

		pipe23_alu_op_r <= pipe23_alu_op_r;
		pipe23_alu_src_r <= pipe23_alu_src_r;
		pipe23_branch_r <= pipe23_branch_r;
		pipe23_func3_r <= pipe23_func3_r;
		pipe23_func7_r <= pipe23_func7_r;
		pipe23_immediate_r <= pipe23_immediate_r;
		pipe23_jal_r <= pipe23_jal_r;
		pipe23_mem_read_r <= pipe23_mem_read_r;
		pipe23_jalr_r <= pipe23_jalr_r;
		pipe23_mem_to_reg_r <= pipe23_mem_to_reg_r;
		pipe23_mem_write_r <= pipe23_mem_write_r;
		pipe23_nextPC_r <= pipe23_nextPC_r;
		pipe23_reg_data_1_r <= pipe23_reg_data_1_r;
		pipe23_reg_data_2_r <= pipe23_reg_data_2_r;
		pipe23_reg_write_r <= pipe23_reg_write_r;
		pipe23_write_number_r <= pipe23_write_number_r;
		pipe23_BP_r <= pipe23_BP_r;
		pipe23_PC_r <= pipe23_PC_r;
		pipe23_reg1_r <= pipe23_reg1_r;
		pipe23_reg2_r <= pipe23_reg2_r;
		pipe23_instruction12_r <= pipe23_instruction12_r;


		pipe34_alu_output_r <= pipe34_alu_output_r;
		pipe34_branch_r <= pipe34_branch_r;
		pipe34_jal_r <= pipe34_jal_r;
		pipe34_jalr_r <= pipe34_jalr_r;
		pipe34_mem_read_r <= pipe34_mem_read_r;
		pipe34_mem_write_r <= pipe34_mem_write_r;
		pipe34_reg_data_2_r <= pipe34_reg_data_2_r;
		pipe34_reg_write_r <= pipe34_reg_write_r;
		pipe34_write_number_r <= pipe34_write_number_r;
		pipe34_mem_to_reg_r <= pipe34_mem_to_reg_r;
		pipe34_nextPC_r <= pipe34_nextPC_r;

		pipe45_mem_to_reg_r <= pipe45_mem_to_reg_r;
		pipe45_reg_write_data_r <= pipe45_reg_write_data_r;
		pipe45_reg_write_r <= pipe45_reg_write_r;
		pipe45_write_number_r <= pipe45_write_number_r;
	
	end
end

    
endmodule


module ALU (
		clk,
		rst_n,
		data_1,
		data_2,
		ctrl,
		alu_output,
		cpu_stall,
		mul_stall
	);

	//paramter declaration
	parameter ADD = 4'b0001; //ADDI //SW //LW
	parameter SUB = 4'b0010; //BEQ
	parameter SLT= 4'b0011; //BNE //SLTI
	parameter AND = 4'b0100; //ANDI
	parameter OR = 4'b0101; //ORI
	parameter XOR = 4'b0110;//XORI
	parameter SLLI = 4'b0111;
	parameter SRAI = 4'b1000;
	parameter SRLI =4'b1001;
	parameter MUL = 4'b1010;


	//i-o declaration
	input clk, rst_n, cpu_stall;
	input [31:0] data_1, data_2;
	input [3:0] ctrl;

	output [31:0] alu_output;
	output mul_stall;

	//register declaration
	reg[31:0] alu_out;
	reg mul_valid;
	wire [31:0] mul_out;
	//output assignment
	assign alu_output = alu_out;

	// ALUCtrl[0] =  OP[4] & funct3[2] & funct3[1] & (!funct3[0])
	// ALUCtrl[1] = !(OP[4] & (!OP[3]) & funct3[1])
	// ALUCtrl[2] = ((!OP[4]) & (!funct3[1])) | (funct7[5] & OP[4])
	// ALUCtrl[3] = OP[4] & (!funct3[2]) & funct3[1]
	// assign alu_ctrl[0] = ctrl[1] & ctrl[4] & ctrl[3] & (!ctrl[2]);
	// assign alu_ctrl[1] = !(ctrl[1] & (!ctrl[0]) & ctrl[3]);
	// assign alu_ctrl[2] = ((!ctrl[1]) & (!ctrl[3])) | (ctrl[5] & ctrl[1]);
	// assign alu_ctrl[3] = ctrl[1] & (!ctrl[4]) & ctrl[3];

	Wallace mul(
		.clk(clk),
		.rst_n(rst_n),
		.valid(mul_valid),
		.data_1(data_1),
		.data_2(data_2),
		.mul_out(mul_out),
		.cpu_stall(cpu_stall),
		.mul_stall(mul_stall)
	);
	//Combinational Circuit
	always @(*) begin
		mul_valid = 0;
		case (ctrl)
			ADD :begin //ADDI
				alu_out = $signed(data_1) + $signed(data_2);
				//$display("ADD");
			end 
			SUB: begin
				alu_out = $signed(data_1) - $signed(data_2);
			end
			SLT: begin
				if($signed(data_1) < $signed(data_2))begin
					alu_out = 1;
				end else begin
					alu_out = 0;
				end
			end
			AND: begin
				alu_out = data_1 & data_2;
			end
			OR: begin
				alu_out = data_1 | data_2;
			end
			XOR: begin
				alu_out = data_1 ^ data_2;
			end
			SLLI: begin
				alu_out = data_1 << data_2[4:0];
			end
			SRAI: begin
				alu_out = $signed(data_1) >>> data_2[4:0];
			end
			SRLI: begin
				alu_out = data_1 >> data_2[4:0];
			end
			MUL: begin
				alu_out = mul_out;
				mul_valid = 1;
			end
			default: begin
				alu_out = 0;
			end
		endcase
		//$display("ALU ouput is %d", alu_output);
	end
    
endmodule

module Control (
		instruction,
		write_enable,
		mem_write,
		mem_read,
		branch,
		jal,
		jalr,
		mem_to_reg,
		alu_src,
		alu_op
	);

	//parameter declaration
	parameter JAL = 7'b1101111;
	parameter JALR = 7'b1100111;
	parameter BEQ = 7'b1100011;
	parameter RTYPE = 7'b0110011;
	parameter ITYPE = 7'b0010011;
	parameter LW = 7'b0000011;
	parameter SW = 7'b0100011;
	parameter NOP = 7'b0000000;


	// i-o declaration
	input [6:0] instruction;

	output write_enable, mem_write, mem_read, branch, jal, jalr, mem_to_reg, alu_src;
	output [1:0] alu_op;

	//register declaration
	reg w_e, m_w, m_r, br, j, j_r, m_t_r, a_s;
	reg [1:0] a_op;

	// output assignment
	assign write_enable = w_e;
	assign mem_write = m_w;
	assign mem_read = m_r;
	assign branch = br;
	assign jal = j;
	assign jalr = j_r;
	assign mem_to_reg = m_t_r;
	assign alu_src = a_s;
	assign alu_op = a_op;
	// assign write_enable = (instruction[0] | (instruction[3] & instruction[2]) | ((!instruction[3]) & (!instruction[2])));
	// assign mem_write = ((!instruction[4]) & instruction[3] & (!instruction[2])) ;
	// assign branch = (instruction[4] & (!instruction[0]));
	// assign jal = instruction[1];
	// assign jalr = (!instruction[1]) & instruction[0];
	// assign mem_to_reg = (!instruction[3]);
	// assign alu_src = ((!instruction[3]) | (!instruction[4]) & (!instruction[2]));

	//combinational logic
	always @(*) begin
	    case (instruction)
		
	        JAL: begin
	            w_e = 1; //write PC+4 to register
	            m_w = 0;
				m_r = 0;
	            br = 0;
	            j = 1;
	            j_r = 0;
	            m_t_r = 0;
	            a_s = 0; 
				a_op = 2'b00;
	            //$display("JAL");
	        end
	        JALR: begin
	            w_e = 1; //write PC+4 to register
	            m_w = 0;
				m_r = 0;
	            br = 0;
	            j = 0;
	            j_r = 1;
	            m_t_r = 0;
	            a_s = 0; 
				a_op =  2'b00;
	            //$display("JALR");
	        end
	        BEQ: begin // branch if equal
	            w_e = 0;
	            m_w = 0;
				m_r = 0;
	            br = 1;
	            j = 0;
	            j_r = 0;
	            m_t_r = 0;
	            a_s = 0;
				a_op =  2'b10;
	            //$display("BEQ");
	        end
	        LW: begin
	            w_e = 1;
	            m_w = 0;
				m_r = 1;
	            br = 0;
	            j = 0;
	            j_r = 0;
	            m_t_r = 1; //choose read data
	            a_s = 1; //choose immediate
				a_op =  2'b00;
	            //$display("LW");
	        end
	        SW: begin
	            w_e = 0;
	            m_w = 1;
				m_r = 0;
	            br = 0;
	            j = 0;
	            j_r = 0;
	            m_t_r = 0; 
	            a_s = 1; //choose immediate
				a_op =  2'b00;
	            //$display("SW");
	        end
	        RTYPE: begin 
	            w_e = 1;
	            m_w = 0;
				m_r = 0;
	            br = 0;
	            j = 0;
	            j_r = 0;
	            m_t_r = 0;
	            a_s = 0;
				a_op =  2'b01;
	            //$display("RTYPE");
	        end
			ITYPE: begin
				w_e = 1;
	            m_w = 0;
				m_r = 0;
	            br = 0;
	            j = 0;
	            j_r = 0;
	            m_t_r = 0;
	            a_s = 1;
				a_op =  2'b11;
			end
	        default: begin // select NOP as default
	            w_e = 0;
	            m_w = 0;
				m_r = 0;
	            br = 0;
	            j = 0;
	            j_r = 0;
	            m_t_r = 0;
	            a_s = 0;
				a_op =  2'b00;
	        end
	   endcase
	end

endmodule

module Reg_file (
		clk,
		rst_n,
		read_1, //index of registers to be read
		read_2,
		write_number, // index of register to be written
		write_enable, // RegWrite signal from Control
		write_data, // number to be written
		read_data_1, // data read from registers
		read_data_2
	);

	// i-o declarations
	input clk, rst_n;
	input [4:0] read_1, read_2, write_number;
	input [31:0] write_data;
	input write_enable;

	output [31:0] read_data_1, read_data_2;

	integer i;

	//register declaration
	reg [31:0] reg_r [0:31];
	reg [31:0] reg_w [0:31];

	reg [31:0] readwrite1;
	reg [31:0] readwrite2;

	//output assignment
	assign read_data_1 = readwrite1;
	assign read_data_2 = readwrite2;

	//Combinational Circuit
	always @(*) begin
		for(i = 0; i < 32; i = i+1)begin
			reg_w[i] = reg_r[i];
			// if(write_enable) begin
			//     reg_w[write_number] = write_data;
			//     //$display("loaded data %d into register %d", reg_w[write_number], write_number);
			// end
		end
		readwrite1 = reg_r[read_1];
		readwrite2 = reg_r[read_2];
		if(write_enable) begin
				reg_w[write_number] = write_data;
				//$display("loaded data %d into register %d", reg_w[write_number], write_number);
				if(write_number == read_1 && (|write_number)) begin
					readwrite1 = write_data;
				end else begin
					readwrite1 = reg_r[read_1];
				end
				if(write_number == read_2 && (|write_number)) begin
					readwrite2 = write_data;
				end else begin
					readwrite2 = reg_r[read_2];
				end
		end else begin
			reg_w[write_number] = reg_r[write_number];
			readwrite1 = reg_r[read_1];
			readwrite2 = reg_r[read_2];
		end
		//$display("reg1 is %d, reg2 is %d, data1 is %b, data2 is %b", read_1, read_2, read_data_1, read_data_2);
		//$display("x1 is %d", reg_r[1]);
	end

	//Sequential Circuit
	always @(posedge clk) begin
		if(!rst_n)begin
			for(i = 0; i < 32; i = i+1)begin
				reg_r[i] <= 0;
			end
		end else begin
			reg_r[0] <= 0;
			for(i = 1; i < 32; i = i+1)begin
				reg_r[i] <= reg_w[i];
			end
		end
	end
endmodule

//==================== CACHE ========================
//leo cache
module cache_dm(
	    clk,
	    proc_reset,
	    proc_read,
	    proc_write,
	    proc_addr,
	    proc_rdata,
	    proc_wdata,
	    proc_stall,
	    mem_read,
	    mem_write,
	    mem_addr,
	    mem_rdata,
	    mem_wdata,
	    mem_ready
	);
	
	//==== input/output definition ============================
	    input          clk;
	    // processor interface
	    input          proc_reset;
	    input          proc_read, proc_write;
	    input   [29:0] proc_addr;
	    input   [31:0] proc_wdata;
	    output reg        proc_stall;
	    output reg [31:0] proc_rdata;
	    // memory interface
	    input  [127:0] mem_rdata;
	    input          mem_ready;
	    output reg        mem_read, mem_write;
	    output reg [27:0] mem_addr;
	    output reg [127:0] mem_wdata;
	
	//==== parameter definition ================================
	    parameter S_IDLE = 3'd0;
	    parameter S_READ_MISS = 3'd1;
	    parameter S_WRITE_MISS = 3'd2;
	    parameter S_WRITE_BACK = 3'd3;
	//==== wire/reg definition ================================
	    reg      [2:0] state, state_nxt;
	    reg    [127:0] block[0:7], block_nxt[0:7];
	    reg     [24:0] tag[0:7], tag_nxt[0:7];
	    reg            block_update[0:7], block_update_nxt[0:7];
	//==== combinational circuit ==============================
	//NL
	always @(*) begin
	    state_nxt = state;
	    case(state)
	        S_IDLE: begin
	            case({proc_read, proc_write})
	                2'b10: begin
	                    if( tag[proc_addr[4:2]] != proc_addr[29:5] ) begin
	                        if( block_update[proc_addr[4:2]] ) begin
	                            state_nxt = S_WRITE_BACK;
	                        end
	                        else begin
	                            state_nxt = S_READ_MISS;
	                        end
	                    end
	                    else begin
	                        state_nxt = S_IDLE;
	                    end
	                end
	                2'b01: begin
	                    if( tag[proc_addr[4:2]] != proc_addr[29:5] ) begin
	                        if( block_update[proc_addr[4:2]] ) begin
	                            state_nxt = S_WRITE_BACK;
	                        end
	                        else begin
	                            state_nxt = S_WRITE_MISS;
	                        end
	                    end
	                    else begin
	                        state_nxt = S_IDLE;
	                    end
	                end
	                default: begin
	                    state_nxt = S_IDLE;
	                end
	            endcase
	        end
	        S_READ_MISS: begin
	            if( mem_ready ) begin
	                state_nxt = S_IDLE;
	            end
	            else begin
	                state_nxt = S_READ_MISS;
	            end
	        end
	        S_WRITE_MISS: begin
	            if( mem_ready ) begin
	                state_nxt = S_IDLE;
	            end
	            else begin
	                state_nxt = S_WRITE_MISS;
	            end
	        end
	        S_WRITE_BACK: begin
	            if( mem_ready ) begin
	                if(proc_read) begin
	                    state_nxt = S_READ_MISS;
	                end
	                else begin
	                    state_nxt = S_WRITE_MISS;
	                end
	            end
	            else begin
	                state_nxt = S_WRITE_BACK;
	            end
	        end
	        default: begin
	            state_nxt = S_IDLE;
	        end
	    endcase
	end
	//OL
	integer i;
	always @(*) begin //OL
	    case(proc_addr[1:0])
	        2'd0: proc_rdata = block[proc_addr[4:2]][31:0]  ;
	        2'd1: proc_rdata = block[proc_addr[4:2]][63:32] ;
	        2'd2: proc_rdata = block[proc_addr[4:2]][95:64] ;
	        2'd3: proc_rdata = block[proc_addr[4:2]][127:96];
	    endcase
	    proc_stall = 0;
	    mem_read   = 0;
	    mem_write  = 0;
	    mem_addr   = 0;
	    mem_wdata  = 0;
	    for(i = 0; i < 8; i = i + 1) begin
	        block_nxt[i] = block[i];
	        tag_nxt[i] = tag[i];
	        block_update_nxt[i] = block_update[i];
	    end
	    case(state)
	        S_IDLE: begin
	            case({proc_read, proc_write})
	                2'b10: begin
	                    case({tag[proc_addr[4:2]] != proc_addr[29:5], block_update[proc_addr[4:2]]})
	                        2'b11: begin
	                            mem_write = 1;
	                            mem_addr = {tag[proc_addr[4:2]], proc_addr[4:2]};
	                            mem_wdata = block[proc_addr[4:2]];
	                            proc_stall = 1;
	                        end
	                        2'b10: begin
	                            mem_read = 1;
	                            mem_addr = proc_addr[29:2];
	                            proc_stall = 1;
	                        end
	                        default: begin
	                            case(proc_addr[1:0])
	                                2'd0: proc_rdata = block[proc_addr[4:2]][31:0]  ;
	                                2'd1: proc_rdata = block[proc_addr[4:2]][63:32] ;
	                                2'd2: proc_rdata = block[proc_addr[4:2]][95:64] ;
	                                2'd3: proc_rdata = block[proc_addr[4:2]][127:96];
	                            endcase
	                        end
	                    endcase

	                    
	                end
	                2'b01: begin
	                    if( tag[proc_addr[4:2]] != proc_addr[29:5] ) begin
	                        if( block_update[proc_addr[4:2]] ) begin
	                            mem_write = 1;
	                            mem_addr = {tag[proc_addr[4:2]], proc_addr[4:2]};
	                            mem_wdata = block[proc_addr[4:2]];
	                            proc_stall = 1;
	                        end
	                        else begin
	                            mem_read = 1;
	                            mem_addr = proc_addr[29:2];
	                            proc_stall = 1;
	                        end
	                    end
	                    else begin
	                        block_update_nxt[proc_addr[4:2]] = 1;
	                        case(proc_addr[1:0])
	                            2'd0: block_nxt[proc_addr[4:2]][31:0]  = proc_wdata;
	                            2'd1: block_nxt[proc_addr[4:2]][63:32] = proc_wdata;
	                            2'd2: block_nxt[proc_addr[4:2]][95:64] = proc_wdata;
	                            2'd3: block_nxt[proc_addr[4:2]][127:96] = proc_wdata;
	                        endcase
	                    end
	                end
	                default: begin
	                    proc_stall = 0;
	                end
	            endcase
	        end
	        S_READ_MISS: begin
	            if( mem_ready ) begin
	                block_nxt[proc_addr[4:2]] = mem_rdata;
	                tag_nxt[proc_addr[4:2]] = proc_addr[29:5];
	                block_update_nxt[proc_addr[4:2]] = 0;
	                case(proc_addr[1:0])
	                    2'd0: proc_rdata = mem_rdata[31:0]  ;
	                    2'd1: proc_rdata = mem_rdata[63:32] ;
	                    2'd2: proc_rdata = mem_rdata[95:64] ;
	                    2'd3: proc_rdata = mem_rdata[127:96];
	                endcase
	            end
	            else begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                proc_stall = 1;
	            end
	        end
	        S_WRITE_MISS: begin
	            if( mem_ready ) begin
	                tag_nxt[proc_addr[4:2]] = proc_addr[29:5];
	                block_update_nxt[proc_addr[4:2]] = 1;
	                block_nxt[proc_addr[4:2]] = mem_rdata;
	                case(proc_addr[1:0])
	                    2'd0: block_nxt[proc_addr[4:2]][31:0]   = proc_wdata;
	                    2'd1: block_nxt[proc_addr[4:2]][63:32]  = proc_wdata;
	                    2'd2: block_nxt[proc_addr[4:2]][95:64]  = proc_wdata;
	                    2'd3: block_nxt[proc_addr[4:2]][127:96] = proc_wdata;
	                endcase
	            end
	            else begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                proc_stall = 1;
	            end
	        end
	        S_WRITE_BACK: begin
	            if( mem_ready ) begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                proc_stall = 1;
	            end
	            else begin
	                mem_write = 1;
	                mem_addr = {tag[proc_addr[4:2]], proc_addr[4:2]};
	                mem_wdata = block[proc_addr[4:2]];
	                proc_stall = 1;
	            end
	        end
	        default: begin
	            proc_stall = 0;
	        end
	    endcase
	end
	//==== sequential circuit =================================
	always@( posedge clk ) begin
	    if( proc_reset ) begin
	        state <= S_IDLE;
	        for(i = 0; i < 8; i = i + 1) begin
	            block[i] <= 0;
	            tag[i] <= 25'h1FFFFFF;
	            block_update[i] <= 0;
	        end
	    end
	    else begin
	        state <= state_nxt;
	        for(i = 0; i < 8; i = i + 1) begin
	            block[i] <= block_nxt[i];
	            tag[i] <= tag_nxt[i];
	            block_update[i] <= block_update_nxt[i];
	        end
	    end
	end
endmodule

module cache_2way(
	    clk,
	    proc_reset,
	    proc_read,
	    proc_write,
	    proc_addr,
	    proc_rdata,
	    proc_wdata,
	    proc_stall,
	    mem_read,
	    mem_write,
	    mem_addr,
	    mem_rdata,
	    mem_wdata,
	    mem_ready
	);
	
	//==== input/output definition ============================
	    input          clk;
	    // processor interface
	    input          proc_reset;
	    input          proc_read, proc_write;
	    input   [29:0] proc_addr;
	    input   [31:0] proc_wdata;
	    output reg        proc_stall;
	    output reg [31:0] proc_rdata;
	    // memory interface
	    input  [127:0] mem_rdata;
	    input          mem_ready;
	    output reg        mem_read, mem_write;
	    output reg [27:0] mem_addr;
	    output reg [127:0] mem_wdata;
	
	//==== parameter definition ================================
	    parameter S_IDLE = 2'd0;
	    parameter S_READ_MISS = 2'd1;
	    parameter S_WRITE_MISS = 2'd2;
	    parameter S_WRITE_BACK = 2'd3;
	//==== wire/reg definition ================================
	    reg      [1:0] state, state_nxt;
	    reg    [127:0] block[0:15][0:1], block_nxt[0:15][0:1];
	    reg     [23:0] tag[0:15][0:1], tag_nxt[0:15][0:1];
	    reg            block_update[0:15][0:1], block_update_nxt[0:15][0:1];
	    //reg            LRU[0:3], LRU_nxt[0:3];
	//==== combinational circuit ==============================
	//NL
	always @(*) begin
	    state_nxt = state;
	    case(state)
	        S_IDLE: begin
	            case({proc_read, proc_write})
	                2'b10: begin
	                    case({tag[proc_addr[5:2]][0] == proc_addr[29:6], block_update[proc_addr[5:2]][0], tag[proc_addr[5:2]][1] == proc_addr[29:6], block_update[proc_addr[5:2]][1]})
	                        4'b0000: state_nxt = S_READ_MISS; 
	                        4'b0001: state_nxt = S_WRITE_BACK;
	                        4'b0100: state_nxt = S_READ_MISS;
	                        4'b0101: state_nxt = S_WRITE_BACK;
	                        default:  state_nxt = S_IDLE;
	                    endcase
	                end
	                2'b01: begin
	                    case({tag[proc_addr[5:2]][0] == proc_addr[29:6], block_update[proc_addr[5:2]][0], tag[proc_addr[5:2]][1] == proc_addr[29:6], block_update[proc_addr[5:2]][1]})
	                        4'b0000: state_nxt = S_WRITE_MISS; 
	                        4'b0001: state_nxt = S_WRITE_BACK;
	                        4'b0100: state_nxt = S_WRITE_MISS;
	                        4'b0101: state_nxt = S_WRITE_BACK;
	                        default:  state_nxt = S_IDLE;
	                    endcase
	                end
	                default: begin
	                    state_nxt = S_IDLE;
	                end
	            endcase
	        end
	        S_READ_MISS: begin
	            if( mem_ready ) begin
	                state_nxt = S_IDLE;
	            end
	            else begin
	                state_nxt = S_READ_MISS;
	            end
	        end
	        S_WRITE_MISS: begin
	            if( mem_ready ) begin
	                state_nxt = S_IDLE;
	            end
	            else begin
	                state_nxt = S_WRITE_MISS;
	            end
	        end
	        S_WRITE_BACK: begin
	            case({mem_ready, proc_read})
	                2'b11: begin
	                    state_nxt = S_READ_MISS;
	                end
	                2'b10: begin
	                    state_nxt = S_WRITE_MISS;
	                end
	                default: begin
	                    state_nxt = S_WRITE_BACK;
	                end
	            endcase
	        end
	        default: begin
	            state_nxt = S_IDLE;
	        end
	    endcase
	end
	//OL
	integer i,j;
	always @(*) begin //OL
	    case(proc_addr[1:0])
	        2'd0: proc_rdata = block[proc_addr[5:2]][0][31:0]  ;
	        2'd1: proc_rdata = block[proc_addr[5:2]][0][63:32] ;
	        2'd2: proc_rdata = block[proc_addr[5:2]][0][95:64] ;
	        2'd3: proc_rdata = block[proc_addr[5:2]][0][127:96];
	    endcase
	    proc_stall = 0;
	    mem_read   = 0;
	    mem_write  = 0;
	    mem_addr   = 0;
	    mem_wdata  = 0;
	    for(i = 0; i < 16; i = i + 1) begin
	        for(j = 0; j < 2; j = j + 1) begin
	            block_nxt[i][j] = block[i][j];
	            tag_nxt[i][j] = tag[i][j];
	            block_update_nxt[i][j] = block_update[i][j];
	        end
	    end
	    case(state)
	        S_IDLE: begin
	            case({proc_read, proc_write})
	                2'b10: begin
	                    case({tag[proc_addr[5:2]][0] == proc_addr[29:6], block_update[proc_addr[5:2]][0], tag[proc_addr[5:2]][1] == proc_addr[29:6], block_update[proc_addr[5:2]][1]})
	                        4'b0000, 4'b0100: begin
	                            mem_read = 1;
	                            mem_addr = proc_addr[29:2];
	                            proc_stall = 1;
	                        end
	                        4'b0001,4'b0101: begin
	                            mem_write = 1;
	                            mem_addr = {tag[proc_addr[5:2]][1], proc_addr[5:2]};
	                            mem_wdata = block[proc_addr[5:2]][1];
	                            proc_stall = 1;
	                        end
	                        default:  begin
	                            if(tag[proc_addr[5:2]][0] == proc_addr[29:6]) begin
	                                case(proc_addr[1:0])
	                                    2'd0: proc_rdata = block[proc_addr[5:2]][0][31:0]  ;
	                                    2'd1: proc_rdata = block[proc_addr[5:2]][0][63:32] ;
	                                    2'd2: proc_rdata = block[proc_addr[5:2]][0][95:64] ;
	                                    2'd3: proc_rdata = block[proc_addr[5:2]][0][127:96];
	                                endcase
	                            end else begin
	                                case(proc_addr[1:0])
	                                    2'd0: proc_rdata = block[proc_addr[5:2]][1][31:0]  ;
	                                    2'd1: proc_rdata = block[proc_addr[5:2]][1][63:32] ;
	                                    2'd2: proc_rdata = block[proc_addr[5:2]][1][95:64] ;
	                                    2'd3: proc_rdata = block[proc_addr[5:2]][1][127:96];
	                                endcase
	                                block_nxt[proc_addr[5:2]][0] = block[proc_addr[5:2]][1];
	                                tag_nxt[proc_addr[5:2]][0] = tag[proc_addr[5:2]][1];
	                                block_update_nxt[proc_addr[5:2]][0] = block_update[proc_addr[5:2]][1];
	                                block_nxt[proc_addr[5:2]][1] = block[proc_addr[5:2]][0];
	                                tag_nxt[proc_addr[5:2]][1] = tag[proc_addr[5:2]][0];
	                                block_update_nxt[proc_addr[5:2]][1] = block_update[proc_addr[5:2]][0];
	                            end
	                        end
	                    endcase
	                end
	                2'b01: begin
	                    case({tag[proc_addr[5:2]][0] == proc_addr[29:6], block_update[proc_addr[5:2]][0], tag[proc_addr[5:2]][1] == proc_addr[29:6], block_update[proc_addr[5:2]][1]})
	                        4'b0000, 4'b0100: begin
	                            mem_read = 1;
	                            mem_addr = proc_addr[29:2];
	                            proc_stall = 1;
	                        end
	                        4'b0001,4'b0101: begin
	                            mem_write = 1;
	                            mem_addr = {tag[proc_addr[5:2]][1], proc_addr[5:2]};
	                            mem_wdata = block[proc_addr[5:2]][1];
	                            proc_stall = 1;
	                        end
	                        default:  begin
	                            if(tag[proc_addr[5:2]][0] == proc_addr[29:6]) begin
	                                block_update_nxt[proc_addr[5:2]][0] = 1;
	                                case(proc_addr[1:0])
	                                    2'd0: block_nxt[proc_addr[5:2]][0][31:0]  = proc_wdata;
	                                    2'd1: block_nxt[proc_addr[5:2]][0][63:32] = proc_wdata;
	                                    2'd2: block_nxt[proc_addr[5:2]][0][95:64] = proc_wdata;
	                                    2'd3: block_nxt[proc_addr[5:2]][0][127:96] = proc_wdata;
	                                endcase
	                            end else begin
	                                block_update_nxt[proc_addr[5:2]][0] = 1;
	                                block_update_nxt[proc_addr[5:2]][1] = block_update[proc_addr[5:2]][0];
	                                tag_nxt[proc_addr[5:2]][0] = tag[proc_addr[5:2]][1];
	                                tag_nxt[proc_addr[5:2]][1] = tag[proc_addr[5:2]][0];
	                                block_nxt[proc_addr[5:2]][1] = block[proc_addr[5:2]][0];
	                                block_nxt[proc_addr[5:2]][0] = block[proc_addr[5:2]][1];
	                                case(proc_addr[1:0])
	                                    2'd0: block_nxt[proc_addr[5:2]][0][31:0]  = proc_wdata;
	                                    2'd1: block_nxt[proc_addr[5:2]][0][63:32] = proc_wdata;
	                                    2'd2: block_nxt[proc_addr[5:2]][0][95:64] = proc_wdata;
	                                    2'd3: block_nxt[proc_addr[5:2]][0][127:96] = proc_wdata;
	                                endcase
	                                end
	                        end
	                    endcase
	
	                end
	                default: begin
	                    proc_stall = 0;
	                end
	            endcase
	        end
	        S_READ_MISS: begin
	            if( mem_ready ) begin
	                block_nxt[proc_addr[5:2]][0] = mem_rdata;
	                block_nxt[proc_addr[5:2]][1] = block[proc_addr[5:2]][0];
	                tag_nxt[proc_addr[5:2]][0] = proc_addr[29:6];
	                tag_nxt[proc_addr[5:2]][1] = tag[proc_addr[5:2]][0];
	                block_update_nxt[proc_addr[5:2]][0] = 0;
	                block_update_nxt[proc_addr[5:2]][1] = block_update[proc_addr[5:2]][0];

	                case(proc_addr[1:0])
	                    2'd0: proc_rdata = mem_rdata[31:0]  ;
	                    2'd1: proc_rdata = mem_rdata[63:32] ;
	                    2'd2: proc_rdata = mem_rdata[95:64] ;
	                    2'd3: proc_rdata = mem_rdata[127:96];
	                endcase
	            end
	            else begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                proc_stall = 1;
	            end
	        end
	        S_WRITE_MISS: begin
	            if( mem_ready ) begin
	                block_nxt[proc_addr[5:2]][0] = mem_rdata;
	                block_nxt[proc_addr[5:2]][1] = block[proc_addr[5:2]][0];
	                tag_nxt[proc_addr[5:2]][0] = proc_addr[29:6];
	                tag_nxt[proc_addr[5:2]][1] = tag[proc_addr[5:2]][0];
	                block_update_nxt[proc_addr[5:2]][0] = 1;
	                block_update_nxt[proc_addr[5:2]][1] = block_update[proc_addr[5:2]][0];

	                case(proc_addr[1:0])
	                    2'd0: block_nxt[proc_addr[5:2]][0][31:0]   = proc_wdata;
	                    2'd1: block_nxt[proc_addr[5:2]][0][63:32]  = proc_wdata;
	                    2'd2: block_nxt[proc_addr[5:2]][0][95:64]  = proc_wdata;
	                    2'd3: block_nxt[proc_addr[5:2]][0][127:96] = proc_wdata;
	                endcase
	            end
	            else begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                proc_stall = 1;
	            end
	        end
	        S_WRITE_BACK: begin
	            if( mem_ready ) begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                proc_stall = 1;
	            end
	            else begin
	                mem_write = 1;
	                mem_addr = {tag[proc_addr[5:2]][1], proc_addr[5:2]};
	                mem_wdata = block[proc_addr[5:2]][1];
	                proc_stall = 1;
	            end
	        end
	        default: begin
	            proc_stall = 0;
	        end
	    endcase
	end
	//==== sequential circuit =================================
	always@( posedge clk ) begin
	    if( proc_reset ) begin
	        state <= S_IDLE;
	        for(i = 0; i < 16; i = i + 1) begin
	            for(j = 0; j < 2; j = j + 1) begin
	                block[i][j] <= 0;
	                tag[i][j] <= 25'h1FFFFFF;
	                block_update[i][j] <= 0;
	            end
	        end
	    end
	    else begin
	        state <= state_nxt;
	        for(i = 0; i < 16; i = i + 1) begin
	            for(j = 0; j < 2; j = j + 1) begin
	                block[i][j] <= block_nxt[i][j];
	                tag[i][j] <= tag_nxt[i][j];
	                block_update[i][j] <= block_update_nxt[i][j];
	            end
	        end
	    end
	end

endmodule


//ilo cache
module i_cache(
	    clk,
	    proc_reset,
	    proc_read,
	    proc_write,
	    proc_addr,
	    proc_rdata,
	    proc_wdata,
	    proc_stall,
	    mem_read,
	    mem_write,
	    mem_addr,
	    mem_rdata,
	    mem_wdata,
	    mem_ready,
		compressed
	);
	
	//==== input/output definition ============================
	    input          clk;
	    // processor interface
	    input          proc_reset;
	    input          proc_read, proc_write;
	    input   [30:0] proc_addr;
	    input   [31:0] proc_wdata;
	    output reg     proc_stall;
	    output reg [31:0] proc_rdata;
	    // memory interface
	    input  [127:0] mem_rdata;
	    input          mem_ready;
	    output reg       mem_read, mem_write;
	    output reg [27:0] mem_addr;
	    output reg [127:0] mem_wdata;
		output reg compressed;
	
	//==== wire/reg definition ================================
	
	    reg [15:0] cache_w[0:15][0:7], cache_r [0:15][0:7]; // 16 block cache , 4 words per block => 8 half words per block
	    reg [31-4-4:0] c_mem_addr_w[0:15], c_mem_addr_r [0:15]; //memory address of the words in the cache
	    reg c_loaded_w[0:15], c_loaded_r[0:15]; // whether cache is loaded
	
	
		//reg [31:0] cache_data1;
		reg [31:0] cache_data;
		reg [4:0] rs1, rd;
		reg [4:0] select;
		reg [3:0] load_index;
		reg [4:0] read_index;
		reg [3:0] read_offset;
		reg [24:0] read_address;

		reg valid_r, valid_w;
	
	    integer i;
	
		wire [2:0] word_offset;
		wire [3:0] index; // allow for overflow
	
	//==== combinational circuit ==============================
	
	assign word_offset = proc_addr[2:0];
	assign index = proc_addr[6:3];
	
	
	// proc-addr 4-2 : cache index
	// proc-addr 1-0 : word offset
	// proc-addr 29-5 : cache block memory address 
	// proc-addr 29-2 : cache output memory address
	
	always @(*) begin
	    //default assignments
		
		load_index = index;
		read_index = index + 1;
		//read_address = proc_addr[30:6] + read_index[3];
		read_offset = word_offset + 1;
	
	    for(i = 0; i < 16; i = i + 1) begin
	        // load cache memory
	        c_mem_addr_w[i] = c_mem_addr_r[i];
	
	        // load cache
	        cache_w[i][0] = cache_r[i][0];
	        cache_w[i][1] = cache_r[i][1];
	        cache_w[i][2] = cache_r[i][2];
	        cache_w[i][3] = cache_r[i][3];
			cache_w[i][4] = cache_r[i][4];
	        cache_w[i][5] = cache_r[i][5];
	        cache_w[i][6] = cache_r[i][6];
	        cache_w[i][7] = cache_r[i][7];
	
	        c_loaded_w[i] = c_loaded_r[i];
	    end
	
	    // default output assignment
	    mem_read = 0;
	    mem_write = 0;
	    mem_addr = proc_addr[30:3];
	    mem_wdata = 0;
	
	    proc_stall = 0;
	    proc_rdata = 0;
	
		cache_data = 0;
		//cache_data1 = 0;
		//rs1 = 0;
		compressed = 0;
		valid_w = valid_r;
	
	    // read data
	    if(proc_read) begin
	        // if cache has the correct address
	        proc_stall = 1;
	        proc_rdata = 0;
	        // if(c_mem_addr_r[index] == proc_addr[30:6] && c_loaded_r[index]) begin // if cache hit
			// 	if(word_offset == 7) begin // check for cross block problems
			// 		read_index = index + 1;
			// 		if(c_loaded_r[read_index[2:0]] && c_mem_addr_r[read_index[2:0]] == (proc_addr[30:6] + read_index[3]) ) begin
			// 			proc_rdata = {cache_r[read_index[2:0]][0], cache_r[index][word_offset]};
			// 			proc_stall = 0;
			// 		end else begin
			// 			proc_stall = 1;
			// 			mem_addr = proc_addr[30:3] + 1;
			// 			load_index = read_index[2:0];
			// 		end
	
			// 	end else begin
			// 		proc_rdata = {cache_r[index][word_offset + 1], cache_r[index][word_offset]};
			// 		proc_stall = 0;
			// 	end
					
	        // end 
			// if(c_mem_addr_r[index] == proc_addr[30:6] && c_loaded_r[index] ) begin // if cache hit
			// 	 // check for cross block problems
				
			// 	if(c_loaded_r[read_index[2:0]] && c_mem_addr_r[read_index[2:0]] == read_address) begin
			// 		proc_rdata = {cache_r[read_index[2:0]][0], cache_r[index][7]};
			// 		proc_stall = 0;
			// 	end else begin
			// 		proc_stall = 1;
			// 		mem_addr = proc_addr[30:3] + 1;
			// 		load_index = read_index[2:0];
			// 	end
					
			// end else
			if(c_mem_addr_r[index] == proc_addr[30:7] && c_loaded_r[index]) begin
				cache_data = {cache_r[index + read_offset[3]][read_offset[2:0]], cache_r[index][word_offset]};
				proc_stall = 0;
				valid_w = 1;
			end 
	
			
			
	    end
	
		// decode instruction
		if(cache_data[1] & cache_data[0]) begin // if 11 no decode
			//{cache_data1[7:0], cache_data1[15:8], cache_data1[23:16], cache_data1[31:24]};
			if((word_offset == 7) && valid_r && !((c_mem_addr_r[read_index[3:0]] == (proc_addr[30:7] + read_index[4]) && c_loaded_r[read_index[3:0]]))) begin
				proc_stall = 1;
				load_index = read_index[3:0];
				mem_addr = proc_addr[30:3] + 1;
			end else begin
				proc_rdata = cache_data;
			end
		
		end else begin // else decompress
			// rs1 = rs' + 8 (access x8 - x15)
			//cache_data = {cache_data1[7:0], cache_data1[15:8], cache_data1[23:16], cache_data1[31:24]};
			compressed = 1;
			rs1 = cache_data[9:7] + 8;
			rd = cache_data[4:2] + 8;
			select = {cache_data[15:13],cache_data[1:0]};
			case(select)
				5'b10010:begin //ADD,JALR,JR, MV
				if(cache_data[12]) begin
					if(|cache_data[6:2])begin //ADD
						proc_rdata = {7'b0_000_000, cache_data[6:2], cache_data[11:7], 3'b000,cache_data[11:7], 7'b0110011};
					end else begin // JALR = jalr, x1, rs, 0
						proc_rdata = {11'b00_000_000_000, cache_data[11:7], 3'b000, 5'b00001, 7'b1100111};
					end
				end else begin
					if(|cache_data[6:2])begin // MV = ADDI 0
						proc_rdata = {11'b00_000_000_000, cache_data[6:2], 3'b000, cache_data[11:7], 7'b0010011};
					end else begin // JR = jalr, x0, rs, 0
						proc_rdata = {11'b00_000_000_000, cache_data[11:7], 3'b000, 5'b00000, 7'b1100111};
					end
				end
				end
				5'b00010:begin // SLLI
				proc_rdata = {7'b0_000_000, cache_data[6:2], cache_data[11:7], 3'b001, cache_data[11:7], 7'b0010011 };
				end
				5'b00001:begin // ADDI or NOP
				if(|cache_data[11:7]) begin //ADDI
					proc_rdata = {{7{cache_data[12]}}, cache_data[6:2], cache_data[11:7],3'b000 , cache_data[11:7], 7'b0010011 };
				end else begin //NOP
					proc_rdata = 32'b010011;
				end
				end
				5'b10101:begin //J = jal, x0, offset
				//immediate = cache_data[12, 8, 10:9, 6, 7, 2, 11, 5:3]
				proc_rdata = {cache_data[12], cache_data[8], cache_data[10:9], cache_data[6], cache_data[7], cache_data[2], cache_data[11], cache_data[5:3] , {9{cache_data[12]}} ,5'b00000,7'b1101111}; // sign extend immediate
				end
				5'b00101:begin //JAL = jal, x1, offset
				proc_rdata = {cache_data[12], cache_data[8], cache_data[10:9], cache_data[6], cache_data[7], cache_data[2], cache_data[11], cache_data[5:3] , {9{cache_data[12]}} ,5'b00001,7'b1101111};
				end
				5'b10001:begin //SRAI, SRLI, ANDI
				if(cache_data[11]) begin //ANDI
					proc_rdata = {{7{cache_data[12]}}, cache_data[6:2], rs1, 3'b111, rs1, 7'b0010011};
				end else if(cache_data[10]) begin //SRAI
					proc_rdata = {7'b0_100_000, cache_data[6:2], rs1, 3'b101, rs1, 7'b0010011};
				end else begin //SRLI
					proc_rdata = {7'b0_000_000, cache_data[6:2], rs1, 3'b101, rs1, 7'b0010011};
				end
				end
				5'b11001:begin //BEQZ
				proc_rdata = {{4{cache_data[12]}}, cache_data[6:5], cache_data[2], 5'b00_000, rs1, 3'b000, cache_data[11:10], cache_data[4:3], cache_data[12],  7'b1100011};
				end
				5'b11101:begin //BNEZ
				proc_rdata = {{4{cache_data[12]}}, cache_data[6:5], cache_data[2], 5'b00_000, rs1, 3'b001, cache_data[11:10], cache_data[4:3], cache_data[12],  7'b1100011};
				end
				5'b01000:begin //LW
				proc_rdata = { 5'b00_000, cache_data[5], cache_data[12:10], cache_data[6], 2'b00, rs1, 3'b010, rd, 7'b0000011};
				end
				5'b11000:begin //SW
				proc_rdata = { 5'b00_000, cache_data[5], cache_data[12], rd, rs1, 3'b010, cache_data[11:10], cache_data[6], 2'b00, 7'b0100011};
				end
				default:begin
				proc_rdata = 32'b0;
			end
			endcase
		end

		if(proc_stall) begin // cache miss => load data
	            mem_read = 1;
	            //mem_addr = proc_addr[30:3];
	            if(mem_ready) begin // memory is ready to read
	                mem_read = 0;
	
	                // update cache memory
	                c_mem_addr_w[load_index] =  mem_addr[27:4]; 
	
	                // update cache data
					// also convert endianness
	                cache_w[load_index][1] = {mem_rdata[7:0], mem_rdata[15:8]};
	                cache_w[load_index][0] = {mem_rdata[23:16], mem_rdata[31:24]};
	                cache_w[load_index][3] = {mem_rdata[39:32], mem_rdata[47:40]};
	                cache_w[load_index][2] = {mem_rdata[55:48], mem_rdata[63:56]};
					cache_w[load_index][5] = {mem_rdata[71:64], mem_rdata[79:72]};
	                cache_w[load_index][4] = {mem_rdata[87:80], mem_rdata[95:88]};
	                cache_w[load_index][7] = {mem_rdata[103:96], mem_rdata[111:104]};
	                cache_w[load_index][6] = {mem_rdata[119:112], mem_rdata[127:120]};
					// DONT CONVERT OTHERWISE EVERYTHING IS WRONG
					// cache_w[index][0] = mem_rdata[15:0];
	                // cache_w[index][1] = mem_rdata[31:16];
	                // cache_w[index][2] = mem_rdata[47:32];
	                // cache_w[index][3] = mem_rdata[63:48];
					// cache_w[index][4] = mem_rdata[79:64];
	                // cache_w[index][5] = mem_rdata[95:80];
	                // cache_w[index][6] = mem_rdata[111:96];
	                // cache_w[index][7] = mem_rdata[127:112];
	
	                // update cache status
	                c_loaded_w[load_index] = 1;
					if(load_index != index) begin
						valid_w = 0;
					end
	
	            end
	        end
	
	end
	
	//==== sequential circuit =================================
	always@( posedge clk ) begin
	    if( proc_reset ) begin    
	        for(i = 0; i < 16; i = i + 1) begin
	            // reset cache memory
	            c_mem_addr_r[i] <= 0;
	
	            // reset cache
	            cache_r[i][0] <= 0;
	            cache_r[i][1] <= 0;
	            cache_r[i][2] <= 0;
	            cache_r[i][3] <= 0;
				cache_r[i][4] <= 0;
	            cache_r[i][5] <= 0;
	            cache_r[i][6] <= 0;
	            cache_r[i][7] <= 0;
	
	            // reset cache status
	            c_loaded_r[i] <= 0;
	        end
	
	        // reset control signal
			valid_r <= 0;
	    end
	    else begin
	        for(i = 0; i < 16; i = i + 1) begin
	            // load cache memory
	            c_mem_addr_r[i] <= c_mem_addr_w[i];
	
	            // load cache
	            cache_r[i][0] <= cache_w[i][0];
	            cache_r[i][1] <= cache_w[i][1];
	            cache_r[i][2] <= cache_w[i][2];
	            cache_r[i][3] <= cache_w[i][3];
				cache_r[i][4] <= cache_w[i][4];
	            cache_r[i][5] <= cache_w[i][5];
	            cache_r[i][6] <= cache_w[i][6];
	            cache_r[i][7] <= cache_w[i][7];
	
	            // load cache status
	            c_loaded_r[i] <= c_loaded_w[i];
	        end

			valid_r <= valid_w;
	    end
	end

endmodule


module d_cache(
	    clk,
	    proc_reset,
	    proc_read,
	    proc_write,
	    proc_addr,
	    proc_rdata,
	    proc_wdata,
	    proc_stall,
	    mem_read,
	    mem_write,
	    mem_addr,
	    mem_rdata,
	    mem_wdata,
	    mem_ready
	);
	
	//==== input/output definition ============================
	    input          clk;
	    // processor interface
	    input          proc_reset;
	    input          proc_read, proc_write;
	    input   [29:0] proc_addr;
	    input   [31:0] proc_wdata;
	    output reg       proc_stall;
	    output reg[31:0] proc_rdata;
	    // memory interface
	    input  [127:0] mem_rdata;
	    input          mem_ready;
	    output reg        mem_read, mem_write;
	    output reg [27:0] mem_addr;
	    output reg [127:0] mem_wdata;
	
	//==== wire/reg definition ================================

	    reg [31:0] cache_w[0:3][0:1][0:3], cache_r [0:3][0:1][0:3]; // 4 set cache , 2 blocks per set, 4 words per block
	    reg [31-4-2:0] c_mem_addr_w[0:3][0:1], c_mem_addr_r [0:3][0:1]; //memory address of the words in the cache
	    reg c_loaded_w[0:3][0:1], c_loaded_r[0:3][0:1]; // whether cache is loaded
	    reg dirty_w[0:3][0:1], dirty_r[0:3][0:1];
	    reg replace_w [0:3], replace_r[0:3];
	    integer i;
	
	//==== combinational circuit ==============================

	// proc-addr 3-2 : cache index
	// proc-addr 1-0 : word offset
	// proc-addr 29-4 : cache block memory address 
	// proc-addr 29-2 : cache output memory address

	always @(*) begin
	    //default assignments
	    for(i = 0; i < 4; i = i + 1) begin
	        // load cache memory
	        c_mem_addr_w[i][0] = c_mem_addr_r[i][0];
	        c_mem_addr_w[i][1] = c_mem_addr_r[i][1];

	        // load cache
	        cache_w[i][0][0] = cache_r[i][0][0];
	        cache_w[i][0][1] = cache_r[i][0][1];
	        cache_w[i][0][2] = cache_r[i][0][2];
	        cache_w[i][0][3] = cache_r[i][0][3];

	        cache_w[i][1][0] = cache_r[i][1][0];
	        cache_w[i][1][1] = cache_r[i][1][1];
	        cache_w[i][1][2] = cache_r[i][1][2];
	        cache_w[i][1][3] = cache_r[i][1][3];

	        c_loaded_w[i][0] = c_loaded_r[i][0];
	        c_loaded_w[i][1] = c_loaded_r[i][1];

	        dirty_w[i][0] = dirty_r[i][0];
	        dirty_w[i][1] = dirty_r[i][1];

	        replace_w[i] = replace_r[i];
	    end

	    // default output assignment
	    mem_read = 0;
	    mem_write = 0;
	    mem_addr = 0;
	    mem_wdata = 0;

	    proc_stall = 0;
	    proc_rdata = 0;

	    // read data
	    if(proc_read) begin
	        // if cache has the correct address
	        proc_stall = 1;
	
	        if(c_mem_addr_r[proc_addr[3:2]][0] == proc_addr[29:4] && c_loaded_r[proc_addr[3:2]][0]) begin // if cache hit at 0
	            proc_stall = 0;
	            proc_rdata = cache_r[proc_addr[3:2]][0][proc_addr[1:0]];

	            // replacement policy
	            replace_w[proc_addr[3:2]] = 1'b1;

	        end else if(c_mem_addr_r[proc_addr[3:2]][1] == proc_addr[29:4] && c_loaded_r[proc_addr[3:2]][1])  begin // if cache hit at 1
	            proc_stall = 0;
	            proc_rdata = cache_r[proc_addr[3:2]][1][proc_addr[1:0]];

	            // replacement policy
	            replace_w[proc_addr[3:2]] = 1'b0;

	        end else begin // cache miss
	            // if dirty, first write back before load
	            if(dirty_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]])begin
	                mem_write = 1;

	                //write back to original address as fetched from memory
	                mem_addr = {c_mem_addr_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]],proc_addr[3:2]};

	                // write block to memory
	                mem_wdata = {cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][3] , 
	                                cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][2] , 
	                                cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][1] , 
	                                cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][0]} ;

	                if(mem_ready) begin // memory is ready to write
	                    mem_write = 0;

	                    //update dirty status
	                    dirty_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]] = 0;
	                end
	            end else begin
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                if(mem_ready) begin // memory is ready to read
	                    mem_read = 0;

	                    // update cache memory
	                    c_mem_addr_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]] =  proc_addr[29:4]; 

	                    // update cache data
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][0] = mem_rdata[31:0];
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][1] = mem_rdata[63:32];
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][2] = mem_rdata[95:64];
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][3] = mem_rdata[127:96];

	                    // update cache status
	                    c_loaded_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]] = 1;

	                    // replacement policy
	                    //replace_w[proc_addr[3:2]] = !replace_r[proc_addr[3:2]];
	                end
	            end 
	        end
	    end

	    // write data
	    else if(proc_write) begin
	        // load data block first
	        proc_stall = 1;

	        if(c_mem_addr_r[proc_addr[3:2]][0] == proc_addr[29:4] && c_loaded_r[proc_addr[3:2]][0]) begin // if cache hit at 0
	            cache_w[proc_addr[3:2]][0][proc_addr[1:0]] = proc_wdata; // update written data

	            //write through
	            dirty_w[proc_addr[3:2]][0] = 1'b1;
	            proc_stall = 0;

	            // replacement policy
	            replace_w[proc_addr[3:2]] = 1'b1;
	        end else if(c_mem_addr_r[proc_addr[3:2]][1] == proc_addr[29:4] && c_loaded_r[proc_addr[3:2]][1])  begin // if cache hit at 0
	            cache_w[proc_addr[3:2]][1][proc_addr[1:0]] = proc_wdata; // update written data

	            //write through
	            dirty_w[proc_addr[3:2]][1] = 1'b1;
	            proc_stall = 0;

	            // replacement policy
	            replace_w[proc_addr[3:2]] = 1'b0;
	        end else begin
	            // if dirty, first write back
	            if(dirty_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]])begin
	                mem_write = 1;

	                //write back to original address as fetched from memory
	                mem_addr = {c_mem_addr_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]],proc_addr[3:2]};

	                // write block to memory
	                mem_wdata = {cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][3] , 
	                                cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][2] , 
	                                cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][1] , 
	                                cache_r[proc_addr[3:2]][replace_r[proc_addr[3:2]]][0]} ;

	                if(mem_ready) begin // memory is ready to write
	                    mem_write = 0;

	                    //update dirty status
	                    dirty_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]] = 0;
	                end
	            end else begin
	                // load data block
	                mem_read = 1;
	                mem_addr = proc_addr[29:2];
	                if(mem_ready) begin // memory is ready to read
	                    mem_read = 0;

	                    // update cache memory
	                    c_mem_addr_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]] =  proc_addr[29:4]; 

	                    // update cache data
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][0] = mem_rdata[31:0];
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][1] = mem_rdata[63:32];
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][2] = mem_rdata[95:64];
	                    cache_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]][3] = mem_rdata[127:96];

	                    // update cache status
	                    c_loaded_w[proc_addr[3:2]][replace_r[proc_addr[3:2]]] = 1;

	                    // replacement policy
	                    //replace_w[proc_addr[3:2]] = !replace_r[proc_addr[3:2]];
	                end
	            end
	        end
	    end

	end

	//==== sequential circuit =================================
	always@( posedge clk ) begin
	    if( proc_reset ) begin    
	        for(i = 0; i < 4; i = i + 1) begin
	            // load cache memory
	            c_mem_addr_r[i][0] <= 0;
	            c_mem_addr_r[i][1] <= 0;

	            // load cache
	            cache_r[i][0][0] <= 0;
	            cache_r[i][0][1] <= 0;
	            cache_r[i][0][2] <= 0;
	            cache_r[i][0][3] <= 0;

	            cache_r[i][1][0] <= 0;
	            cache_r[i][1][1] <= 0;
	            cache_r[i][1][2] <= 0;
	            cache_r[i][1][3] <= 0;

	            c_loaded_r[i][0] <= 0;
	            c_loaded_r[i][1] <= 0;

	            dirty_r[i][0] <= 0;
	            dirty_r[i][1] <= 0;

	            replace_r[i] <= 0;
	        end
	    end
	    else begin
	        for(i = 0; i < 4; i = i + 1) begin
	            // load cache memory
	            c_mem_addr_r[i][0] <= c_mem_addr_w[i][0];
	            c_mem_addr_r[i][1] <= c_mem_addr_w[i][1];

	            // load cache
	            cache_r[i][0][0] <= cache_w[i][0][0];
	            cache_r[i][0][1] <= cache_w[i][0][1];
	            cache_r[i][0][2] <= cache_w[i][0][2];
	            cache_r[i][0][3] <= cache_w[i][0][3];

	            cache_r[i][1][0] <= cache_w[i][1][0];
	            cache_r[i][1][1] <= cache_w[i][1][1];
	            cache_r[i][1][2] <= cache_w[i][1][2];
	            cache_r[i][1][3] <= cache_w[i][1][3];

	            c_loaded_r[i][0] <= c_loaded_w[i][0];
	            c_loaded_r[i][1] <= c_loaded_w[i][1];

	            dirty_r[i][0] <= dirty_w[i][0];
	            dirty_r[i][1] <= dirty_w[i][1];

	            replace_r[i] <= replace_w[i];
	        end
	    end
	end

endmodule
//============== Multiplication Unit ===================
module Wallace(
		clk,
		rst_n,
		valid,
		data_1,
		data_2,
		mul_out,
		cpu_stall,
		mul_stall
	);
	parameter PIPE_COUNT = 1;

	input clk,rst_n,valid,cpu_stall;
	input [31:0] data_1, data_2;
	output [31:0] mul_out;
	output mul_stall;

	reg [31:0] stage_w[0:8][0:31],stage_r[0:8][0:31];
	reg sign_w, sign_r;
	reg [31:0] unsign_data_1, unsign_data_2;
	reg [31:0] mul_result_w, mul_result_r;
	reg [3:0]  counter, counter_nxt;
	reg [31:0] data_1_r, data_2_r;

	integer i,j;

	assign mul_stall = valid && (counter!=PIPE_COUNT);
	assign mul_out = mul_result_r;

	//counter
	always @(*) begin
		counter_nxt= counter;
		if(valid && (counter!=PIPE_COUNT)) begin
			counter_nxt = counter + 1;
		end else if((counter == PIPE_COUNT) && !cpu_stall) begin
			counter_nxt = 0;
		end else begin
			counter_nxt = counter;
		end
	end

	always @(*) begin
		mul_result_w = data_1 * data_2;
	end

	//sign
	// always @(*) begin
	// 	sign_w = data_1[31] ^ data_2[31];
	// 	if(data_1[31]) begin
	// 		unsign_data_1 = -data_1;
	// 	end else begin
	// 		unsign_data_1 = data_1;
	// 	end
	// 	if(data_2[31]) begin
	// 		unsign_data_2 = -data_2;
	// 	end else begin
	// 		unsign_data_2 = data_2;
	// 	end
	// end

	
	// //wallace tree
	// always @(*) begin
	// 	for(j=0;j<9;j=j+1) begin
	// 		for(i = 0; i<32; i = i + 1) begin
	// 			stage_w[j][i] = 0;
	// 		end
	// 	end
	// 	//initialize
	// 	for(i = 0; i<32; i = i + 1) begin
	// 		stage_w[0][i] = (unsign_data_1[i])? unsign_data_2 << i : 0;
	// 	end

	// 	//tree reduction
	// 	for(j=0;j<8;j=j+1) begin
	// 		for(i = 0; i<10; i = i + 1) begin
	// 			stage_w[j+1][2*i] = stage_r[j][3*i] ^ stage_r[j][3*i+1] ^ stage_r[j][3*i+2];
	// 			stage_w[j+1][2*i+1][31:1] = (stage_r[j][3*i][30:0] & stage_r[j][3*i+1][30:0]) | (stage_r[j][3*i+1][30:0] & stage_r[j][3*i+2][30:0]) | (stage_r[j][3*i][30:0] & stage_r[j][3*i+2][30:0]);
	// 		end
	// 		stage_w[j+1][20] = stage_r[j][30];
	// 		stage_w[j+1][21] = stage_r[j][31];
	// 	end
		
	// 	//final output
	// 	mul_result_w = (sign_r)? -(stage_r[8][0] + stage_r[8][1]) : stage_r[8][0] + stage_r[8][1];
	// end

	//pipeline control
	always @(*) begin
		// sign_r = sign_w;
		for(i = 0; i<32; i = i + 1) begin
			stage_r[0][i] = stage_w[0][i];
			stage_r[1][i] = stage_w[1][i];
			stage_r[2][i] = stage_w[2][i];
			stage_r[3][i] = stage_w[3][i];
			stage_r[4][i] = stage_w[4][i];
			// stage_r[5][i] = stage_w[5][i];
			stage_r[6][i] = stage_w[6][i];
			stage_r[7][i] = stage_w[7][i];
			stage_r[8][i] = stage_w[8][i];
			mul_result_r = mul_result_w;
		end
	end

	//sequential logic
	always @(posedge clk) begin
		if(!rst_n) begin
			// sign_r <= 0;
			counter <= 0;
			// data_1_r <= 0;
			// data_2_r <= 0;
			for(i = 0; i<32; i = i + 1) begin
				// stage_r[0][i] <= 0;
				// stage_r[1][i] <= 0;
				// stage_r[2][i] <= 0;
				// stage_r[3][i] <= 0;
				// stage_r[4][i] <= 0;
				// stage_r[5][i] <= 0;
				// stage_r[6][i] <= 0;
				// stage_r[7][i] <= 0;
				// stage_r[8][i] <= 0;
				// mul_result_r <= mul_result_w;
			end
		end else begin
			// sign_r <= sign_w;
			counter <= counter_nxt;
			// if(valid && (counter == 0)) begin
			// 	data_1_r <= data_1;
			// 	data_2_r <= data_2;
			// end else begin
			// 	data_1_r <= data_1_r;
			// 	data_2_r <= data_2_r;
			// end
			for(i = 0; i<32; i = i + 1) begin
				// stage_r[0][i] <= stage_w[0][i];
				// stage_r[1][i] <= stage_w[1][i];
				// stage_r[2][i] <= stage_w[2][i];
				// stage_r[3][i] <= stage_w[3][i];
				// stage_r[4][i] <= stage_w[4][i];
				// stage_r[5][i] <= stage_w[5][i];
				// stage_r[6][i] <= stage_w[6][i];
				// stage_r[7][i] <= stage_w[7][i];
				// stage_r[8][i] <= stage_w[8][i];
				// mul_result_r <= mul_result_w;
			end
		end
	end
endmodule

//============== Branch Prediction Unit ================

module BP_nBitHistory_mBitPC_correlation #(
		parameter n=2,
		parameter m=2
	)(
		clk,
		rst_n,
		branch,
		cpu_stall,
		branch_result,
		IF_PC,
		ID_PC,
		branch_predict
	);

	// i-o declarations
	input clk, rst_n;
	input branch;
	input branch_result;
	input cpu_stall;
	input [31:0] IF_PC, ID_PC;
	output branch_predict;

	// register declarations
	reg [1:0] state[0:2**n-1][0:2**m-1], state_nxt[0:2**n-1][0:2**m-1];
	reg       bp;
	reg [n-1:0] true_history,history, history_nxt;
	//output assignment
	assign branch_predict = bp;

	integer i,j;
	
	// next state logic
	always @(*) begin
		for(i = 0; i < 2**n; i = i + 1) begin
			for(j = 0; j < 2**m; j = j + 1) begin
				state_nxt[i][j] = state[i][j];
			end
		end

		if(branch && !cpu_stall) begin
			case({state[history][ID_PC[m-1:0]],branch_result})
				3'b000: state_nxt[history][ID_PC[m-1:0]] = 2'b00;
				3'b001: state_nxt[history][ID_PC[m-1:0]] = 2'b01;
				3'b010: state_nxt[history][ID_PC[m-1:0]] = 2'b00;
				3'b011: state_nxt[history][ID_PC[m-1:0]] = 2'b10;
				3'b100: state_nxt[history][ID_PC[m-1:0]] = 2'b01;
				3'b101: state_nxt[history][ID_PC[m-1:0]] = 2'b11;
				3'b110: state_nxt[history][ID_PC[m-1:0]] = 2'b10;
				3'b111: state_nxt[history][ID_PC[m-1:0]] = 2'b11;
				default: begin
					state_nxt[history][ID_PC[m-1:0]] = state[history][ID_PC[m-1:0]];
				end
			endcase
		end else begin
			for(i = 0; i < 2**n; i = i + 1) begin
				for(j = 0; j < 2**m; j = j + 1) begin
					state_nxt[i][j] = state[i][j];
				end
			end
		end

	end

	//update history
	always @(*) begin
		history_nxt = history;
		if(branch && !cpu_stall) begin
			history_nxt = {history[n-2:0], branch_result};
		end else begin
			history_nxt = history;
		end
	end
	
	// true history
	always @(*) begin
		if(branch) begin
			true_history = {history[n-2:0], branch_result};
		end else begin
			true_history = history;
		end
	end

	// output logic
	always @(*) begin
		bp = 0;
		case(state[true_history][IF_PC[m-1:0]])
			2'b00: bp = 1'b0;
			2'b01: bp = 1'b0;
			2'b10: bp = 1'b1;
			2'b11: bp = 1'b1;
			default: bp = 1'b0;
		endcase
	end
	
	// sequential logic
	always @(posedge clk) begin
		if(!rst_n) begin
			for(i = 0; i < 2**n; i = i + 1) begin
				for(j = 0; j < 2**m; j = j + 1) begin
					state[i][j] <= 2'b10;
				end
			end
			history <= 0;
		end else begin
			for(i = 0; i < 2**n; i = i + 1) begin
				for(j = 0; j < 2**m; j = j + 1) begin
					state[i][j] <= state_nxt[i][j];
				end
			end
			history <= history_nxt;
		end
	end
endmodule

module BP_nbit_2level#(
		parameter n=2
	)(
		clk,
		rst_n,
		branch,
		cpu_stall,
		branch_result,
		branch_predict
	);

	// i-o declarations
	input clk, rst_n;
	input branch;
	input branch_result;
	input cpu_stall;
	output branch_predict;

	// register declarations
	reg [1:0] state[0:2**n-1], state_nxt[0:2**n-1];
	reg       bp;
	reg [n-1:0] true_history,history, history_nxt;
	//output assignment
	assign branch_predict = bp;

	integer i;
	
	// next state logic
	always @(*) begin
		for(i = 0; i < 2**n; i = i + 1) begin
			state_nxt[i] = state[i];
		end

		if(branch && !cpu_stall) begin
			case({state[history],branch_result})
				3'b000: state_nxt[history] = 2'b00;
				3'b001: state_nxt[history] = 2'b01;
				3'b010: state_nxt[history] = 2'b00;
				3'b011: state_nxt[history] = 2'b10;
				3'b100: state_nxt[history] = 2'b01;
				3'b101: state_nxt[history] = 2'b11;
				3'b110: state_nxt[history] = 2'b10;
				3'b111: state_nxt[history] = 2'b11;
				default: begin
					state_nxt[history] = state[history];
				end
			endcase
		end else begin
			for(i = 0; i < 2**n; i = i + 1) begin
				state_nxt[i] = state[i];
			end
		end

	end

	//update history
	always @(*) begin
		history_nxt = history;
		if(branch && !cpu_stall) begin
			history_nxt = {history[n-2:0], branch_result};
		end else begin
			history_nxt = history;
		end
	end
	
	// true history
	always @(*) begin
		if(branch) begin
			true_history = {history[n-2:0], branch_result};
		end else begin
			true_history = history;
		end
	end

	// output logic
	always @(*) begin
		bp = 0;
		case(state[true_history])
			2'b00: bp = 1'b0;
			2'b01: bp = 1'b0;
			2'b10: bp = 1'b1;
			2'b11: bp = 1'b1;
			default: bp = 1'b0;
		endcase
	end
	
	// sequential logic
	always @(posedge clk) begin
		if(!rst_n) begin
			for(i = 0; i < 2**n; i = i + 1) begin
				state[i] <= 2'b10;
			end
			history <= 0;
		end else begin
			for(i = 0; i < 2**n; i = i + 1) begin
				state[i] <= state_nxt[i];
			end
			history <= history_nxt;
		end
	end
endmodule

module BP_Saturation(
		clk,
		rst_n,
		branch,
		cpu_stall,
		branch_result,
		branch_predict
	);

	// i-o declarations
	input clk, rst_n, branch, cpu_stall, branch_result;
	output branch_predict;

	// register declarations
	reg [1:0] state, state_nxt;
	reg       bp;

	//output assignment
	assign branch_predict = bp;

	// next state logic
	always @(*) begin
		state_nxt = state;
		if(branch && !cpu_stall) begin
			case({state,branch_result})
				3'b000: state_nxt = 2'b00;
				3'b001: state_nxt = 2'b01;
				3'b010: state_nxt = 2'b00;
				3'b011: state_nxt = 2'b10;
				3'b100: state_nxt = 2'b01;
				3'b101: state_nxt = 2'b11;
				3'b110: state_nxt = 2'b10;
				3'b111: state_nxt = 2'b11;
				default: begin
					state_nxt = state;
				end
			endcase
		end else begin
			state_nxt = state;
		end
	end
		
	// output logic
	always @(*) begin
		bp = 0;
		case(state)
			2'b00: bp = 1'b0;
			2'b01: bp = 1'b0;
			2'b10: bp = 1'b1;
			2'b11: bp = 1'b1;
			default: bp = 1'b0;
		endcase
	end
	
	// sequential logic
	always @(posedge clk) begin
		if(!rst_n) begin
			state <= 2'b10;
		end else begin
			state <= state_nxt;
		end
	end
endmodule