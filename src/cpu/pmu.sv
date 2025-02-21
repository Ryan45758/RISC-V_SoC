`include "cpu_define.h"
`include "csr_define.h"

// 0x106 SRW scounteren Supervisor counter enable.
// 0x306 MRW mcounteren Machine counter enable.

module pmu (
    input                    clk_free,
    input                    rstn,
    input        [`XLEN-1:0] cpu_id,
    input                    insn_valid,
    input        [      1:0] misa_mxl,
    input        [      1:0] prv,
    input        [     63:0] mtime,
    output logic [     63:0] mcycle,
    
    // CSR interface
    input                    csr_rd_chk, // EXE-stage
    input                    csr_wr_chk, // EXE-stage
    input                    csr_wr,
    input        [     11:0] csr_waddr,
    input        [     11:0] csr_raddr,
    // input        [`XLEN-1:0] csr_wdata,
    input        [`XLEN-1:0] csr_sdata,
    input        [`XLEN-1:0] csr_cdata,
    output logic [`XLEN-1:0] csr_rdata,
    output logic             csr_hit,
    output logic             csr_ill
);


logic [`XLEN-1:0] scounteren;
logic [`XLEN-1:0] mcounteren;
logic [`XLEN-1:0] mhartid;
// logic [     63:0] mcycle;
logic [     63:0] minstret;

assign csr_ill = (misa_mxl == `MISA_MXL_XLEN_64 && (csr_rd_chk || csr_wr_chk) &&
                 (csr_waddr == `CSR_MCYCLEH_ADDR || csr_waddr == `CSR_MINSTRETH_ADDR)) ||
                 (prv < `PRV_M && (csr_rd_chk || csr_wr_chk) && csr_waddr[11:5] == 7'b1100_000 &&
                 ~mcounteren[csr_waddr[4:0]]) ||
                 (prv < `PRV_S && (csr_rd_chk || csr_wr_chk) && csr_waddr[11:5] == 7'b1100_000 &&
                 ~scounteren[csr_waddr[4:0]]);

always_ff @(posedge clk_free or negedge rstn) begin
    if (~rstn)
        scounteren <= `XLEN'b0;
    else if (csr_wr && csr_waddr == `CSR_SCOUNTEREN_ADDR)
        scounteren[0+:32] <= `CSR_WDATA(scounteren[0+:32], 0+:32);
end

always_ff @(posedge clk_free or negedge rstn) begin
    if (~rstn)
        mcounteren <= `XLEN'b0;
    else if (csr_wr && csr_waddr == `CSR_MCOUNTEREN_ADDR)
        mcounteren[0+:32] <= `CSR_WDATA(mcounteren[0+:32], 0+:32);
end

always_ff @(posedge clk_free or negedge rstn) begin
    if (~rstn)
        mcycle            <= 64'b0;
    else if (csr_wr && csr_waddr == `CSR_MCYCLE_ADDR)
        mcycle[ 0+:`XLEN] <= `CSR_WDATA(mcycle[0+:`XLEN], 0+:`XLEN);
    else if (csr_wr && csr_waddr == `CSR_MCYCLEH_ADDR)
        mcycle[32+:   32] <= `CSR_WDATA(mcycle[32+:32], 0+:32);
    else
        mcycle            <= mcycle + 64'b1;
end

always_ff @(posedge clk_free or negedge rstn) begin
    if (~rstn)
        minstret            <= 64'b0;
    else if (csr_wr && csr_waddr == `CSR_MINSTRET_ADDR)
        minstret[ 0+:`XLEN] <= `CSR_WDATA(minstret[ 0+:`XLEN], 0+:`XLEN);
    else if (csr_wr && csr_waddr == `CSR_MINSTRETH_ADDR)
        minstret[32+:   32] <= `CSR_WDATA(minstret[32+:   32], 32+:32);
    else
        minstret            <= minstret + {63'b0, insn_valid};
end

always_ff @(posedge clk_free or negedge rstn) begin
    if (~rstn) mhartid <= `XLEN'b0;
    else       mhartid <= cpu_id;
end

always_comb begin
    csr_rdata = `XLEN'b0;
    csr_hit   = 1'b1;
    case (csr_raddr) 
        `CSR_CYCLE_ADDR:      csr_rdata = mcycle    [ 0+:`XLEN];
        `CSR_CYCLEH_ADDR:     csr_rdata = mcycle    [32+:   32];
        `CSR_TIME_ADDR:       csr_rdata = mtime     [ 0+:`XLEN];
        `CSR_TIMEH_ADDR:      csr_rdata = mtime     [32+:   32];
        `CSR_INSTRET_ADDR:    csr_rdata = minstret  [ 0+:`XLEN];
        `CSR_INSTRETH_ADDR:   csr_rdata = minstret  [32+:   32];
        `CSR_SCOUNTEREN_ADDR: csr_rdata = scounteren;
        `CSR_MCOUNTEREN_ADDR: csr_rdata = mcounteren;
        `CSR_MCYCLE_ADDR:     csr_rdata = mcycle    [ 0+:`XLEN];
        `CSR_MCYCLEH_ADDR:    csr_rdata = mcycle    [32+:   32];
        `CSR_MINSTRET_ADDR:   csr_rdata = minstret  [ 0+:`XLEN];
        `CSR_MINSTRETH_ADDR:  csr_rdata = minstret  [32+:   32];
        `CSR_MVENDORID_ADDR:  csr_rdata = `XLEN'b0;
        `CSR_MARCHID_ADDR:    csr_rdata = `XLEN'b0;
        `CSR_MIMPID_ADDR:     csr_rdata = `XLEN'b0;
        `CSR_MCONFIGPTR_ADDR: csr_rdata = `XLEN'b0;
        `CSR_MHARTID_ADDR:    csr_rdata = mhartid;
        default:              csr_hit   = 1'b0;
    endcase
end

endmodule
