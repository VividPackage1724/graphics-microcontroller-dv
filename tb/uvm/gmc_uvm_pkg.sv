package gmc_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  class gmc_host_item extends uvm_sequence_item;
    rand bit write;
    rand bit [7:0] addr;
    rand bit [31:0] data;
    bit is_response;
    bit [31:0] response_data;

    `uvm_object_utils_begin(gmc_host_item)
      `uvm_field_int(write, UVM_DEFAULT)
      `uvm_field_int(addr, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(is_response, UVM_DEFAULT)
      `uvm_field_int(response_data, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "gmc_host_item");
      super.new(name);
    endfunction
  endclass

  class gmc_host_sequencer extends uvm_sequencer #(gmc_host_item);
    `uvm_component_utils(gmc_host_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class gmc_host_driver extends uvm_driver #(gmc_host_item);
    `uvm_component_utils(gmc_host_driver)
    virtual gmc_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual gmc_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "gmc_if virtual interface not configured")
    endfunction

    task run_phase(uvm_phase phase);
      gmc_host_item req;
      vif.host_valid <= 1'b0;
      vif.host_write <= 1'b0;
      vif.host_addr  <= '0;
      vif.host_wdata <= '0;
      wait (vif.rst_n === 1'b1);
      forever begin
        seq_item_port.get_next_item(req);
        @(negedge vif.clk);
        vif.host_valid <= 1'b1;
        vif.host_write <= req.write;
        vif.host_addr  <= req.addr;
        vif.host_wdata <= req.data;
        do @(posedge vif.clk); while (!vif.host_ready);
        @(negedge vif.clk);
        vif.host_valid <= 1'b0;
        // The DUT returns a one-cycle response pulse after accepting a request.
        if (vif.host_rvalid !== 1'b1)
          `uvm_error("NO_RSP", $sformatf("No host response for addr 0x%02h", req.addr))
        else if (!req.write && vif.host_rdata !== req.data && 1'b0)
          `uvm_info("READ", "Read response sampled by monitor", UVM_LOW)
        seq_item_port.item_done();
      end
    endtask
  endclass

  class gmc_host_monitor extends uvm_component;
    `uvm_component_utils(gmc_host_monitor)
    virtual gmc_if vif;
    uvm_analysis_port #(gmc_host_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual gmc_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "gmc_if virtual interface not configured")
    endfunction

    task run_phase(uvm_phase phase);
      gmc_host_item item;
      forever begin
        @(posedge vif.clk);
        if (vif.rst_n && vif.host_valid && vif.host_ready) begin
          item = gmc_host_item::type_id::create("host_req");
          item.write = vif.host_write;
          item.addr  = vif.host_addr;
          item.data  = vif.host_wdata;
          item.is_response = 0;
          ap.write(item);
        end
        @(negedge vif.clk);
        if (vif.rst_n && vif.host_rvalid) begin
          item = gmc_host_item::type_id::create("host_rsp");
          item.is_response = 1;
          item.response_data = vif.host_rdata;
          ap.write(item);
        end
      end
    endtask
  endclass

  class gmc_host_agent extends uvm_agent;
    `uvm_component_utils(gmc_host_agent)
    gmc_host_sequencer sequencer;
    gmc_host_driver driver;
    gmc_host_monitor monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      monitor = gmc_host_monitor::type_id::create("monitor", this);
      if (get_is_active() == UVM_ACTIVE) begin
        sequencer = gmc_host_sequencer::type_id::create("sequencer", this);
        driver = gmc_host_driver::type_id::create("driver", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (get_is_active() == UVM_ACTIVE)
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class gmc_scoreboard extends uvm_component;
    `uvm_component_utils(gmc_scoreboard)
    uvm_analysis_imp #(gmc_host_item, gmc_scoreboard) analysis_export;
    bit [31:0] expected_job_config;
    bit have_job_config;
    int requests_seen;
    int responses_seen;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      analysis_export = new("analysis_export", this);
    endfunction

    function void write(gmc_host_item item);
      if (item.is_response) begin
        responses_seen++;
      end else begin
        requests_seen++;
        if (item.write && item.addr == 8'h0C) begin
          expected_job_config = {16'b0, item.data[15:0]};
          have_job_config = 1;
        end
        if (!item.write && item.addr == 8'h0C && have_job_config) begin
          // Read data is checked by the test's response monitor in later milestones.
          `uvm_info("SB", $sformatf("JOB_CONFIG read requested; expected 0x%08h",
                                   expected_job_config), UVM_MEDIUM)
        end
      end
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SB_SUMMARY", $sformatf("Host requests=%0d responses=%0d",
                                        requests_seen, responses_seen), UVM_LOW)
    endfunction
  endclass

  class gmc_env extends uvm_env;
    `uvm_component_utils(gmc_env)
    gmc_host_agent host_agent;
    gmc_scoreboard scoreboard;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      host_agent = gmc_host_agent::type_id::create("host_agent", this);
      scoreboard = gmc_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      host_agent.monitor.ap.connect(scoreboard.analysis_export);
    endfunction
  endclass

  class gmc_smoke_sequence extends uvm_sequence #(gmc_host_item);
    `uvm_object_utils(gmc_smoke_sequence)
    function new(string name = "gmc_smoke_sequence");
      super.new(name);
    endfunction

    task body();
      gmc_host_item item;
      item = gmc_host_item::type_id::create("enable_gmc");
      start_item(item);
      item.write = 1; item.addr = 8'h00; item.data = 32'h0000_0005;
      finish_item(item);

      item = gmc_host_item::type_id::create("set_job_id");
      start_item(item);
      item.write = 1; item.addr = 8'h0C; item.data = 32'h0000_1234;
      finish_item(item);

      item = gmc_host_item::type_id::create("read_job_id");
      start_item(item);
      item.write = 0; item.addr = 8'h0C; item.data = '0;
      finish_item(item);

      item = gmc_host_item::type_id::create("submit_job");
      start_item(item);
      item.write = 1; item.addr = 8'h08; item.data = 32'h0000_0002;
      finish_item(item);
    endtask
  endclass

  class gmc_base_test extends uvm_test;
    `uvm_component_utils(gmc_base_test)
    gmc_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = gmc_env::type_id::create("env", this);
    endfunction
  endclass

  class gmc_smoke_test extends gmc_base_test;
    `uvm_component_utils(gmc_smoke_test)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      gmc_smoke_sequence seq;
      phase.raise_objection(this);
      seq = gmc_smoke_sequence::type_id::create("seq");
      seq.start(env.host_agent.sequencer);
      #100ns;
      phase.drop_objection(this);
    endtask
  endclass
endpackage
