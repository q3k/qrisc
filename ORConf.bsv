package ORConf;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;
import BRAM::*;

typedef Vector#(16, Reg#(Word)) RegisterFile;
typedef Bit#(32) Word;

// Register selector.
typedef Bit#(4) OpRegister;

// A description of an Operand - either a register or immediate.
typedef union tagged {
    OpRegister R;
    Word Imm;
} Operand deriving (Bits, FShow);

// Actual instruction set. VLIW (currenttly 72 bits).
typedef union tagged {
    struct {
        Operand from;
        OpRegister to;
    } Move;
    struct {
        Operand addr;
        OpRegister to;
    } Load;
    struct {
        Operand from;
        Operand addr;
    } Store;
    struct {
        Operand from1;
        Operand from2;
        OpRegister to;
    } Add;
} Instruction deriving (Bits, FShow);

typedef struct {
    Word pc;
    Instruction ins;
    Word vop1;
    Word vop2;
} Decoded deriving (Bits, FShow);

// Given an Operand and a RegisterFile state, return the value from the
// described Operand.
function Word resolveOperand(Operand op, RegisterFile rf);
    case (op) matches
        tagged Imm .v: return v;
        tagged R .r: return rf[r];
    endcase
endfunction

module mkCPU(Empty);
    // Define two BRAMs: one for intructions, one for data.
    BRAM_Configure cfg = defaultValue;
    cfg.allowWriteResponseBypass = False;
    cfg.loadFormat = tagged Hex "bram.txt";
    BRAM1Port#(Bit#(8), Bit#(SizeOf#(Instruction))) iram <- mkBRAM1Server(cfg);
    cfg.loadFormat = tagged None;
    BRAM2Port#(Bit#(8), Word) dram <- mkBRAM2Server(cfg);

    // Define register file.
    RegisterFile regs <- replicateM(mkReg(0));
    
    // Interface to register file writeback operations: two RWires that allow a
    // rule to provide a next PC (from fetch) or register writeback (from
    // execute). PC write conflicts get unified by the registerWB rule.
    RWire#(Tuple2#(OpRegister, Word)) regWB <- mkRWire;
    RWire#(Word) regWBPC <- mkRWire;

    // Pipeline FIFOs between fetch/decode and decode/execute stages.
    FIFO#(Word) fFetch <- mkPipelineFIFO;
    FIFO#(Decoded) fDecode <- mkPipelineFIFO;

    // Fetch instruction, emit next PC to writeback logic.
    rule fetch;
        $display("Fetch: %x", regs[0]);
        iram.portA.request.put(BRAMRequest { write: False
                                          , responseOnWrite: False
                                          , address: truncate(regs[0])
                                          , datain: 0
                                          });
        regWBPC.wset(regs[0] + 1);
        fFetch.enq(regs[0]);
    endrule

    // Rule which unifies register file writebacks. Currently there's two
    // possible sources for RF writes: the execute stage (any register write)
    // or the fetch stage (next PC).
    rule registerWB;
        Maybe#(Word) pc = regWBPC.wget();
        let wb = regWB.wget();

        // This could be probably made more generic with a fold.
        case (tuple2(pc, wb)) matches
            { ._, tagged Valid { 0, .wpc } }: begin
                regs[0] <= wpc;
            end
            { tagged Valid .wpc, tagged Valid { .nreg, .wreg } }: begin
                regs[0] <= wpc;
                regs[nreg] <= wreg;
            end
            { tagged Valid .wpc, ._ }: begin
                regs[0] <= wpc;
            end
        endcase
    endrule

    // Decode instruction and schedule data memory fetch.
    rule decode;
        let pc = fFetch.first;
        fFetch.deq();

        let word <- iram.portA.response.get;
        Instruction ins = unpack(word);
        $display("Decode: ", fshow(ins), " at ", fshow(pc));

        // Calculate operand values.
        Maybe#(Operand) op1 = case (ins) matches
            tagged Move .move: return tagged Valid move.from;
            tagged Load .load: return tagged Valid load.addr;
            tagged Store .store: return tagged Valid store.addr;
            tagged Add .add: return tagged Valid add.from1;
        endcase;
        Maybe#(Operand) op2 = case (ins) matches
            tagged Add .add: return tagged Valid add.from2;
            tagged Add .store: return tagged Valid tagged R store.to;
            default: return tagged Invalid;
        endcase;
        Word vop1 = case (op1) matches
            tagged Invalid: return 0;
            tagged Valid .op: return resolveOperand(op, regs);
        endcase;
        Word vop2 = case (op2) matches
            tagged Invalid: return 0;
            tagged Valid .op: return resolveOperand(op, regs);
        endcase;

        // Always fetch data memory.
        dram.portA.request.put(BRAMRequest { write: False
                                          , responseOnWrite: False
                                          , address: truncate(vop1)
                                          , datain: 0
                                          });

        fDecode.enq(Decoded { pc: pc
                            , ins: ins
                            , vop1: vop1
                            , vop2: vop2
                            });
    endrule

    // Execute instruction: write back to register file via registerWB, write
    // to memory if needed, call ALU if needed.
    rule execute;
        let decoded = fDecode.first;
        fDecode.deq();

        let mem <- dram.portA.response.get();

        $display("Execute: ", fshow(decoded));
        case (decoded.ins) matches
            tagged Move .move: begin
                regWB.wset(tuple2(move.to, decoded.vop1));
            end
            tagged Load .load: begin
                regWB.wset(tuple2(load.to, mem));
            end
            tagged Store .store: begin
                dram.portB.request.put(BRAMRequest { write: True
                                                   , responseOnWrite: False
                                                   , address: truncate(decoded.vop2)
                                                   , datain: decoded.vop1
                                                   });
            end
            tagged Add .add: begin
                regWB.wset(tuple2(add.to, decoded.vop1 + decoded.vop2));
            end
        endcase
    endrule
endmodule

module mkTb(Empty);
    Empty cpu <- mkCPU;
    Reg#(int) counter <- mkReg(0);
    rule run;
        if (counter == 100) begin
            $display("Done");
            $finish;
        end
        counter <= counter + 1;
    endrule
endmodule

endpackage
