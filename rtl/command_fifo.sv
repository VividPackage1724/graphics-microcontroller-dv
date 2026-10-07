module command_fifo #(
  parameter int WIDTH = 24,
  parameter int DEPTH = 8,
  parameter int PTR_W = (DEPTH <= 2) ? 1 : $clog2(DEPTH),
  parameter int COUNT_W = $clog2(DEPTH + 1)
) (
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 clear,
  input  logic                 push,
  input  logic [WIDTH-1:0]     din,
  input  logic                 pop,
  output logic [WIDTH-1:0]     dout,
  output logic                 empty,
  output logic                 full,
  output logic [COUNT_W-1:0]   count
);
  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [PTR_W-1:0] rd_ptr, wr_ptr;
  logic do_push, do_pop;

  assign empty = (count == 0);
  assign full  = (count == DEPTH);
  assign dout  = empty ? '0 : mem[rd_ptr];
  assign do_pop  = pop && !empty;
  assign do_push = push && (!full || do_pop);

  function automatic logic [PTR_W-1:0] next_ptr(input logic [PTR_W-1:0] ptr);
    if (ptr == DEPTH-1) next_ptr = '0;
    else                next_ptr = ptr + 1'b1;
  endfunction

  always_ff @(posedge clk) begin
    if (!rst_n || clear) begin
      rd_ptr <= '0;
      wr_ptr <= '0;
      count  <= '0;
    end else begin
      if (do_push) begin
        mem[wr_ptr] <= din;
        wr_ptr <= next_ptr(wr_ptr);
      end
      if (do_pop)
        rd_ptr <= next_ptr(rd_ptr);

      case ({do_push, do_pop})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end
endmodule
