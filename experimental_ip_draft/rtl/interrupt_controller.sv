module interrupt_controller (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       event_complete,
    input  logic       event_error,
    input  logic [1:0] irq_enable,
    input  logic [1:0] irq_clear,
    output logic [1:0] irq_status,
    output logic       irq
);
    // Bit 0: completion; bit 1: error.
    // A new event wins over a simultaneous clear.
    always_ff @(posedge clk) begin
        if (!rst_n)
            irq_status <= 2'b00;
        else
            irq_status <= (irq_status & ~irq_clear)
                        | {event_error, event_complete};
    end

    assign irq = |(irq_status & irq_enable);
endmodule
