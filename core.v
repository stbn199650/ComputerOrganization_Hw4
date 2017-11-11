// top

module core (
			  clk,
              rst,
			  // Instruction Cache
			  IC_stall,
			  IC_Address,
              Instruction,
			  // Data Cache
			  DC_stall,
			  DC_Address,
			  DC_Read_enable,
			  DC_Write_enable,
			  DC_Write_Data,
			  DC_Read_Data
			  );

	parameter data_size = 32;
	parameter mem_size = 16;
	parameter pc_size = 18;
	
	input  clk, rst;
	
	// Instruction Cache
	input  IC_stall;
	output [mem_size-1:0] IC_Address;
	input  [data_size-1:0] Instruction;
	
	// Data Cache
	input  DC_stall;
	output [mem_size-1:0] DC_Address;
	output DC_Read_enable;
	output DC_Write_enable;
	output [data_size-1:0] DC_Write_Data;
    	input  [data_size-1:0] DC_Read_Data;
	
	//PC
	wire [pc_size-1:0] PCout;	 
	wire [pc_size-1:0] PC_add4;
	
	//IF_ID pipe
	wire [pc_size-1:0]   ID_PC;
	wire [data_size-1:0] ID_ir;

	//HDU
	wire PCWrite;			 
	wire IF_IDWrite;
	wire ID_EXWrite;
	wire EX_MWrite;
	wire M_WBWrite;
	wire IF_Flush;
	wire ID_Flush;

	//Controller
	wire [5:0] opcode;
	wire [5:0] funct;
	wire [3:0] ALUOp;
	wire Reg_imm;
	wire RegWrite;
	wire MemtoReg;
	wire MemWrite;
	wire Branch;
	wire Jump;
	wire Jal;
	wire Jr;
	wire Half;

	//Regfile
	wire [4:0] Rd;
	wire [4:0] Rs;
	wire [4:0] Rt;
	wire [data_size-1:0] Rs_Data;
	wire [data_size-1:0] Rt_Data;
	wire [4:0] shamt;

	//Sign_extend
	wire [15:0] imm;
	wire [data_size-1:0] se_imm;
	wire [data_size-1:0] se_DC_Read_Data;
	wire [data_size-1:0] se_M_Rt_Data_temp;

	//ID Mux
	wire [4:0] Rd_Rt_out;
	wire [4:0] WR_out;

	//ID_EX
	wire EX_MemtoReg;
	wire EX_RegWrite;
	wire EX_MemWrite;
	wire EX_Jal;
	wire EX_Reg_imm;
	wire EX_Jump;
	wire EX_Branch;
	wire EX_Jr;
	wire EX_Half;
	wire [pc_size-1:0] EX_PC;
	wire [3:0] EX_ALUOp;
	wire [4:0] EX_shamt;
	wire [data_size-1:0] EX_Rs_Data;
	wire [data_size-1:0] EX_Rt_Data;
	wire [data_size-1:0] EX_se_imm;
	wire [4:0] EX_WR_out;
	wire [4:0] EX_Rs;
	wire [4:0] EX_Rt;

	//Jump_Mux
	wire [pc_size-1:0] BranchAddr;
	wire [pc_size-1:0] JumpAddr;
	wire [1:0] EX_JumpOP;
	wire [pc_size-1:0] PCin;

	//FU
	wire src1_f;
	wire src1_b;
	wire src2_f;
	wire src2_b;
	wire [data_size-1:0] src1_f_Data;
	wire [data_size-1:0] src1_b_Data;
	wire [data_size-1:0] src2_f_Data;	
	wire [data_size-1:0] src2_b_Data;

	//ALU
	wire [data_size-1:0] src1;
	wire [data_size-1:0] src2;	
	wire [data_size-1:0] EX_ALU_result;
	wire EX_Zero;

	//PCplus4_Jal
	wire [pc_size-1:0] EX_PCplus8;

	//EX_M
	wire M_MemtoReg;
	wire M_RegWrite;
	wire M_MemWrite;
	wire M_Jal;
	wire M_Half;
	wire [data_size-1:0] M_ALU_result;
	wire [data_size-1:0] M_Rt_Data;
	wire [data_size-1:0] M_DC_Read_Data;
	wire [data_size-1:0] M_Rt_Data_temp;
	wire [pc_size-1:0] M_PCplus8;
	wire [4:0] M_WR_out;
	wire [data_size-1:0] M_WD_out;

	//M_WB
	wire WB_MemtoReg;
	wire WB_RegWrite;
	wire WB_Half;
	wire [data_size-1:0] WB_DC_Read_Data;
	wire [data_size-1:0] WB_WD_out;
        wire [4:0] WB_WR_out;
	wire [data_size-1:0] WB_Final_WD_out;

	assign IC_Address = PCout[pc_size-1:2];		
	assign opcode = ID_ir[31:26];
	assign funct = ID_ir[5:0];	
	assign Rd = ID_ir[15:11];
	assign Rs = ID_ir[25:21];
	assign Rt = ID_ir[20:16];	
	assign imm = ID_ir[15:0];
	assign shamt = ID_ir[10:6];
	assign src1 = src1_b_Data;
	assign JumpAddr = {EX_se_imm[15:0],2'b0};
	assign DC_Address = M_ALU_result[17:2];
	assign DC_Read_enable = M_MemtoReg;
	assign DC_Write_enable = M_MemWrite;
	assign DC_Write_Data = M_Rt_Data;
	
	PC PC_Component ( 
	.clk(clk), 
	.rst(rst),
	.PCWrite(PCWrite),
	.PCin(PCin), 
	.PCout(PCout)
	);

	ADD#(pc_size) ADD_Plus4 ( .A(PCout), .B(18'd4), .Cout(PC_add4));

	IF_ID IF_ID_Section ( 
	.clk(clk),
	.rst(rst),
	.IF_IDWrite(IF_IDWrite),
	.IF_Flush(IF_Flush),
	.IF_PC(PC_add4),
	.IF_ir(Instruction),
	.ID_PC(ID_PC),
	.ID_ir(ID_ir)
	);

	HDU HDU_Component ( 
	.IC_stall(IC_stall),
	.DC_stall(DC_stall),
	.ID_Rs(Rs),
    	.ID_Rt(Rt),
	.EX_WR_out(EX_WR_out),
	.EX_MemtoReg(EX_MemtoReg),
	.EX_JumpOP(EX_JumpOP),
	.PCWrite(PCWrite),			 
	.IF_IDWrite(IF_IDWrite),
	.ID_EXWrite(ID_EXWrite),
	.EX_MWrite(EX_MWrite),
	.M_WBWrite(M_WBWrite),
	.IF_Flush(IF_Flush),
	.ID_Flush(ID_Flush)
	);

	Controller Controller_Component ( 
	.opcode(opcode),
	.funct(funct),
	.ALUOp(ALUOp),
	.Reg_imm(Reg_imm),
	.RegWrite(RegWrite),
	.MemtoReg(MemtoReg),
	.MemWrite(MemWrite),
	.Branch(Branch),
	.Jump(Jump),
	.Jal(Jal),
	.Jr(Jr),	
	.Half(Half)
	);

	Regfile Regfile_Component ( 
	.clk(clk), 
	.rst(rst),
	.Read_addr_1(Rs),
	.Read_addr_2(Rt),
	.Read_data_1(Rs_Data),
	.Read_data_2(Rt_Data),
	.RegWrite(WB_RegWrite),
	.Write_addr(WB_WR_out),
	.Write_data(WB_Final_WD_out)
	);

	Sign_extend sign_extend_imm ( .in(imm), .out(se_imm));

	Mux2to1#(5) Rd_Rt ( .I0(Rd), .I1(Rt), .S(Reg_imm), .out(Rd_Rt_out));

	Mux2to1#(5) WR ( .I0(Rd_Rt_out), .I1(5'd31), .S(Jal), .out(WR_out));

	ID_EX ID_EX_Section ( 
	.clk(clk), 
	.rst(rst),
	.ID_EXWrite(ID_EXWrite),
	.ID_Flush(ID_Flush),
	.ID_MemtoReg(MemtoReg),
	.ID_RegWrite(RegWrite),
	.ID_MemWrite(MemWrite),
	.ID_Jal(Jal),
	.ID_Reg_imm(Reg_imm),
	.ID_Jump(Jump),
	.ID_Branch(Branch),
	.ID_Jr(Jr),
	.ID_Half(Half),		   
	.ID_PC(ID_PC),
	.ID_ALUOp(ALUOp),
	.ID_shamt(shamt),
	.ID_Rs_data(Rs_Data),
	.ID_Rt_data(Rt_Data),
	.ID_se_imm(se_imm),
	.ID_WR_out(WR_out),
	.ID_Rs(Rs),
	.ID_Rt(Rt),
	.EX_MemtoReg(EX_MemtoReg),
	.EX_RegWrite(EX_RegWrite),
	.EX_MemWrite(EX_MemWrite),
	.EX_Jal(EX_Jal),
	.EX_Reg_imm(EX_Reg_imm),
	.EX_Jump(EX_Jump),
	.EX_Branch(EX_Branch),
	.EX_Jr(EX_Jr),
	.EX_Half(EX_Half),
	.EX_PC(EX_PC),
	.EX_ALUOp(EX_ALUOp),
	.EX_shamt(EX_shamt),
	.EX_Rs_data(EX_Rs_Data),
	.EX_Rt_data(EX_Rt_Data),
	.EX_se_imm(EX_se_imm),
	.EX_WR_out(EX_WR_out),
	.EX_Rs(EX_Rs),
	.EX_Rt(EX_Rt)	
	);

	ADD#(pc_size) ADD_Branch ( .A(EX_PC), .B({EX_se_imm[15:0],2'b0}), .Cout(BranchAddr));

	Mux4to1 PC_Mux ( .I0(PC_add4), .I1(BranchAddr), .I2(src1_b_Data[pc_size-1:0]), .I3(JumpAddr), .S(EX_JumpOP), .out(PCin));

	Jump_Ctrl Jump_Ctrl_Component (
	.Branch(EX_Branch),
    	.Zero(EX_Zero),
    	.Jr(EX_Jr),
    	.Jump(EX_Jump),
    	.JumpOP(EX_JumpOP)
	);

	FU FU_Component ( 
	.EX_Rs(EX_Rs),
    	.EX_Rt(EX_Rt),
	.M_RegWrite(M_RegWrite),
	.M_WR_out(M_WR_out),
	.WB_RegWrite(WB_RegWrite),
	.WB_WR_out(WB_WR_out),
	.src1_f(src1_f),
	.src1_b(src1_b),
	.src2_f(src2_f),
	.src2_b(src2_b)	
	);
	//src1_f=!s_Rs
	Mux2to1#(data_size) src1_f_Mux ( .I0(WB_Final_WD_out), .I1(M_WD_out), .S(src1_f), .out(src1_f_Data));
	//src1_b=EN_Rs
	Mux2to1#(data_size) src1_b_Mux ( .I0(EX_Rs_Data), .I1(src1_f_Data), .S(src1_b), .out(src1_b_Data));
	//src2_f=!s_Rt
	Mux2to1#(data_size) src2_f_Mux ( .I0(WB_Final_WD_out), .I1(M_WD_out), .S(src2_f), .out(src2_f_Data));
	//src2_b=EN_Rt
	Mux2to1#(data_size) src2_b_Mux ( .I0(EX_Rt_Data), .I1(src2_f_Data), .S(src2_b), .out(src2_b_Data));

	Mux2to1#(data_size) Rt_imm ( .I0(src2_b_Data), .I1(EX_se_imm), .S(EX_Reg_imm), .out(src2));

	ALU ALU_Component ( 
	.ALUOp(EX_ALUOp),
	.src1(src1),
	.src2(src2),
	.shamt(EX_shamt),
	.ALU_result(EX_ALU_result),
	.Zero(EX_Zero)
	);

	ADD#(pc_size) ADD_Plus4_2 ( .A(EX_PC), .B(18'd4), .Cout(EX_PCplus8));

	EX_M EX_M_Section ( 
	.clk(clk),
	.rst(rst),
	.EX_MWrite(EX_MWrite),
	.EX_MemtoReg(EX_MemtoReg),
	.EX_RegWrite(EX_RegWrite),
	.EX_MemWrite(EX_MemWrite),
	.EX_Jal(EX_Jal),
	.EX_Half(EX_Half),
	.EX_ALU_result(EX_ALU_result),
	.EX_Rt_data(src2_b_Data),
	.EX_PCplus8(EX_PCplus8),
	.EX_WR_out(EX_WR_out),
	.M_MemtoReg(M_MemtoReg),
	.M_RegWrite(M_RegWrite),
	.M_MemWrite(M_MemWrite),
	.M_Jal(M_Jal),
	.M_Half(M_Half),
	.M_ALU_result(M_ALU_result),
	.M_Rt_data(M_Rt_Data_temp),
	.M_PCplus8(M_PCplus8),
	.M_WR_out(M_WR_out)
	);

	Sign_extend se_Rt( .in({M_Rt_Data_temp[15:0]}), .out(se_M_Rt_Data_temp));

	Mux2to1#(data_size) Rt_Half ( .I0(M_Rt_Data_temp), .I1(se_M_Rt_Data_temp), .S(M_Half), .out(M_Rt_Data));

	Sign_extend se_DC( .in({DC_Read_Data[15:0]}), .out(se_DC_Read_Data));

	Mux2to1#(data_size) DC_Half ( .I0(DC_Read_Data), .I1(se_DC_Read_Data), .S(M_Half), .out(M_DC_Read_Data));

	Mux2to1#(data_size) Jal_RD_Select ( .I0(M_ALU_result), .I1({14'b0,M_PCplus8}), .S(M_Jal), .out(M_WD_out));

	M_WB M_WB_Section ( 
	.clk(clk),
    	.rst(rst),
	.M_WBWrite(M_WBWrite),
	.M_MemtoReg(M_MemtoReg),
	.M_RegWrite(M_RegWrite),
	.M_DM_Read_Data(M_DC_Read_Data),
	.M_WD_out(M_WD_out),
	.M_WR_out(M_WR_out),
	.WB_MemtoReg(WB_MemtoReg),
	.WB_RegWrite(WB_RegWrite),
	.WB_DM_Read_Data(WB_DC_Read_Data),
	.WB_WD_out(WB_WD_out),
    	.WB_WR_out(WB_WR_out)
	);

	Mux2to1#(data_size) DM_RD_Select ( .I0(WB_WD_out), .I1(WB_DC_Read_Data), .S(WB_MemtoReg), .out(WB_Final_WD_out));

endmodule


























