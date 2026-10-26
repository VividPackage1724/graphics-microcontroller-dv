package mc_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum {EV_HOST_ACCEPT, EV_DISPATCH, EV_COMPLETION} mc_event_kind_e;

  class mc_job_transaction extends uvm_sequence_item;
    rand bit [7:0] opcode;
    rand bit [15:0] job_id;
    rand int unsigned stall_cycles;
    mc_event_kind_e event_kind;
    bit completion_status;

    constraint c_stall { stall_cycles inside {[0:20]}; }

    `uvm_object_utils_begin(mc_job_transaction)
      `uvm_field_int(opcode, UVM_ALL_ON)
      `uvm_field_int(job_id, UVM_ALL_ON)
      `uvm_field_int(stall_cycles, UVM_ALL_ON)
      `uvm_field_enum(mc_event_kind_e, event_kind, UVM_ALL_ON)
      `uvm_field_int(completion_status, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="mc_job_transaction");
      super.new(name);
    endfunction
  endclass

  class mc_sequencer extends uvm_sequencer #(mc_job_transaction);
    `uvm_component_utils(mc_sequencer)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
  endclass

  class mc_driver extends uvm_driver #(mc_job_transaction);
    `uvm_component_utils(mc_driver)
    virtual mc_if vif;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual mc_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "mc_if virtual interface was not configured for driver")
    endfunction

    task run_phase(uvm_phase phase);
      mc_job_transaction tr;
      vif.job_valid = 0;
      vif.job_opcode = '0;
      vif.job_id = '0;
      vif.ready_enable = 0;
      forever begin
        seq_item_port.get_next_item(tr);
        // Start every transaction with the downstream sink stalled.
        // This prevents an unintended dispatch before the requested stall begins.
        @(negedge vif.clk);
        vif.ready_enable = 0;

        // Host-side job submission.
        vif.job_opcode = tr.opcode;
        vif.job_id = tr.job_id;
        vif.job_valid = 1;
        do @(posedge vif.clk); while (vif.job_ready !== 1'b1);
        @(negedge vif.clk);
        vif.job_valid = 0;

        // Wait until the DUT presents the command, then stall the sink.
        wait (vif.gpu_cmd_valid === 1'b1);
        vif.ready_enable = 0;
        repeat (tr.stall_cycles) @(negedge vif.clk);
        vif.ready_enable = 1;
        do @(posedge vif.clk); while (!(vif.gpu_cmd_valid && vif.gpu_cmd_ready));
        seq_item_port.item_done();
      end
    endtask
  endclass

  class mc_monitor extends uvm_component;
    `uvm_component_utils(mc_monitor)
    virtual mc_if vif;
    uvm_analysis_port #(mc_job_transaction) ap;
    bit previous_stall;
    bit [7:0] previous_opcode;
    bit [15:0] previous_job_id;

    function new(string name, uvm_component parent);
      super.new(name,parent); ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual mc_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "mc_if virtual interface was not configured for monitor")
    endfunction

    task run_phase(uvm_phase phase);
      mc_job_transaction tr;
      previous_stall = 0;
      forever begin
        @(posedge vif.clk);
        if (!vif.rst_n) begin
          previous_stall = 0;
        end else begin
          if (previous_stall) begin
            if (vif.gpu_cmd_valid !== 1'b1 || vif.gpu_cmd_opcode !== previous_opcode ||
                vif.gpu_cmd_job_id !== previous_job_id)
              `uvm_error("BACKPRESSURE", "Command valid/payload changed while stalled")
          end
          previous_stall = (vif.gpu_cmd_valid && !vif.gpu_cmd_ready);
          if (previous_stall) begin
            previous_opcode = vif.gpu_cmd_opcode;
            previous_job_id = vif.gpu_cmd_job_id;
          end

          if (vif.job_valid && vif.job_ready) begin
            tr = mc_job_transaction::type_id::create("host_event");
            tr.event_kind = EV_HOST_ACCEPT;
            tr.opcode = vif.job_opcode;
            tr.job_id = vif.job_id;
            ap.write(tr);
          end
          if (vif.gpu_cmd_valid && vif.gpu_cmd_ready) begin
            tr = mc_job_transaction::type_id::create("dispatch_event");
            tr.event_kind = EV_DISPATCH;
            tr.opcode = vif.gpu_cmd_opcode;
            tr.job_id = vif.gpu_cmd_job_id;
            ap.write(tr);
          end
          if (vif.completion_valid) begin
            tr = mc_job_transaction::type_id::create("completion_event");
            tr.event_kind = EV_COMPLETION;
            tr.job_id = vif.completion_job_id;
            tr.completion_status = vif.completion_status;
            ap.write(tr);
          end
        end
      end
    endtask
  endclass

  class mc_scoreboard extends uvm_component;
    `uvm_component_utils(mc_scoreboard)
    uvm_analysis_imp #(mc_job_transaction, mc_scoreboard) analysis_export;
    mc_job_transaction accepted_q[$];
    mc_job_transaction dispatched_q[$];
    int dispatch_count;
    int completion_count;

    function new(string name, uvm_component parent);
      super.new(name,parent); analysis_export = new("analysis_export", this);
    endfunction

    function void write(mc_job_transaction tr);
      mc_job_transaction expected;
      case (tr.event_kind)
        EV_HOST_ACCEPT: begin
          expected = mc_job_transaction::type_id::create("expected_job");
          expected.copy(tr);
          expected.completion_status = (tr.opcode == 8'hFF);
          accepted_q.push_back(expected);
          `uvm_info("SCB", $sformatf("Accepted job id=%h opcode=%h", tr.job_id, tr.opcode), UVM_MEDIUM)
        end
        EV_DISPATCH: begin
          if (accepted_q.size() == 0) begin
            `uvm_error("SCB", "Dispatch observed without an accepted host job")
          end else begin
            expected = accepted_q.pop_front();
            if (tr.job_id !== expected.job_id || tr.opcode !== expected.opcode)
              `uvm_error("SCB", $sformatf("Dispatch mismatch: expected id=%h opcode=%h, got id=%h opcode=%h", expected.job_id, expected.opcode, tr.job_id, tr.opcode))
            else
              `uvm_info("SCB", $sformatf("Dispatch matched job id=%h", tr.job_id), UVM_MEDIUM)
            dispatched_q.push_back(expected);
            dispatch_count++;
          end
        end
        EV_COMPLETION: begin
          if (dispatched_q.size() == 0) begin
            `uvm_error("SCB", "Completion observed without a dispatched job")
          end else begin
            expected = dispatched_q.pop_front();
            if (tr.job_id !== expected.job_id)
              `uvm_error("SCB", $sformatf("Completion ID mismatch: expected %h, got %h", expected.job_id, tr.job_id))
            if (tr.completion_status !== expected.completion_status)
              `uvm_error("SCB", $sformatf("Completion status mismatch for job %h: expected %b, got %b", expected.job_id, expected.completion_status, tr.completion_status))
            completion_count++;
            `uvm_info("SCB", $sformatf("Completion matched job id=%h status=%b", tr.job_id, tr.completion_status), UVM_MEDIUM)
          end
        end
      endcase
    endfunction

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (accepted_q.size() != 0)
        `uvm_error("SCB", $sformatf("%0d accepted job(s) were never dispatched", accepted_q.size()))
      if (dispatched_q.size() != 0)
        `uvm_error("SCB", $sformatf("%0d dispatched job(s) never completed", dispatched_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCB_SUMMARY", $sformatf("Dispatches=%0d Completions=%0d", dispatch_count, completion_count), UVM_LOW)
    endfunction
  endclass

  class mc_agent extends uvm_agent;
    `uvm_component_utils(mc_agent)
    mc_sequencer sequencer;
    mc_driver driver;
    mc_monitor monitor;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = mc_monitor::type_id::create("monitor", this);
      if (get_is_active() == UVM_ACTIVE) begin
        sequencer = mc_sequencer::type_id::create("sequencer", this);
        driver = mc_driver::type_id::create("driver", this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active() == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class mc_env extends uvm_env;
    `uvm_component_utils(mc_env)
    mc_agent agent;
    mc_scoreboard scoreboard;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = mc_agent::type_id::create("agent", this);
      scoreboard = mc_scoreboard::type_id::create("scoreboard", this);
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.monitor.ap.connect(scoreboard.analysis_export);
    endfunction
  endclass

  class mc_base_sequence extends uvm_sequence #(mc_job_transaction);
    `uvm_object_utils(mc_base_sequence)
    bit [7:0] opcode;
    bit [15:0] job_id;
    int unsigned stall_cycles;
    function new(string name="mc_base_sequence"); super.new(name); endfunction
    task body();
      mc_job_transaction tr;
      tr = mc_job_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with { opcode == local::opcode; job_id == local::job_id; stall_cycles == local::stall_cycles; })
        `uvm_fatal("RANDFAIL", "Failed to randomize mc_job_transaction")
      finish_item(tr);
    endtask
  endclass

  class mc_backpressure_sequence extends mc_base_sequence;
    `uvm_object_utils(mc_backpressure_sequence)
    function new(string name="mc_backpressure_sequence"); super.new(name); endfunction
    task body(); opcode=8'h12; job_id=16'h0042; stall_cycles=5; super.body(); endtask
  endclass

  class mc_error_sequence extends mc_base_sequence;
    `uvm_object_utils(mc_error_sequence)
    function new(string name="mc_error_sequence"); super.new(name); endfunction
    task body(); opcode=8'hFF; job_id=16'h00E1; stall_cycles=2; super.body(); endtask
  endclass

  class mc_base_test extends uvm_test;
    `uvm_component_utils(mc_base_test)
    mc_env env;
    virtual mc_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = mc_env::type_id::create("env", this);
      if (!uvm_config_db#(virtual mc_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "mc_if virtual interface was not configured for test")
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      // Wait for reset release and allow all transactions to finish.
      wait (vif.rst_n === 1'b1);
      run_sequences();
      repeat (20) @(posedge vif.clk);
      phase.drop_objection(this);
    endtask
    virtual task run_sequences(); endtask
  endclass

  class mc_backpressure_test extends mc_base_test;
    `uvm_component_utils(mc_backpressure_test)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    task run_sequences();
      mc_backpressure_sequence seq;
      seq = mc_backpressure_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
    endtask
  endclass

  class mc_error_test extends mc_base_test;
    `uvm_component_utils(mc_error_test)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    task run_sequences();
      mc_error_sequence seq;
      seq = mc_error_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
    endtask
  endclass

endpackage
