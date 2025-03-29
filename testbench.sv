

import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_seq_item extends uvm_sequence_item;
    rand logic enable;
    logic [3:0] count;

    `uvm_object_utils(counter_seq_item)

    function new(string name = "counter_seq_item");
        super.new(name);
    endfunction
endclass


interface counter_if (input clk, input rst_n);
    logic enable;
    logic [3:0] count;
endinterface

import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_sequence extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_sequence)

    function new(string name = "counter_sequence");
        super.new(name);
    endfunction

    task body();
    counter_seq_item item;
    repeat (10) begin
        item = counter_seq_item::type_id::create("item");
        start_item(item);
        item.enable = 1; // Always enable the counter
        finish_item(item);
    end
endtask
endclass

import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_driver extends uvm_driver #(counter_seq_item);
    `uvm_component_utils(counter_driver)

    virtual counter_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Retrieve the virtual interface from the UVM configuration database
        if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRIVER", "Virtual interface not found!")
    endfunction
virtual task run_phase(uvm_phase phase);
    forever begin
        seq_item_port.get_next_item(req);
        vif.enable <= req.enable; // Drive the enable signal
        @(posedge vif.clk);       // Wait for the next clock edge
        seq_item_port.item_done();
    end
endtask
endclass

import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_monitor extends uvm_monitor;
    `uvm_component_utils(counter_monitor)

    virtual counter_if vif;
    uvm_analysis_port #(counter_seq_item) ap;

    // Declare the coverage group
    covergroup counter_cg;
        option.per_instance = 1;
        coverpoint vif.enable {
            bins enable_high = {1};
            bins enable_low  = {0};
        }
        coverpoint vif.count {
            bins count_values[] = {[0:15]};
        }
        cross vif.enable, vif.count;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        counter_cg = new(); // Initialize the coverage group
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
            `uvm_fatal("MONITOR", "Virtual interface not found!")
    endfunction

    virtual task run_phase(uvm_phase phase);
        counter_seq_item item;
        forever begin
            @(posedge vif.clk);
            item = counter_seq_item::type_id::create("item");
            item.enable = vif.enable; // Capture the enable signal
            item.count = vif.count;   // Capture the count signal
            ap.write(item);           // Send the item to the scoreboard
            counter_cg.sample();     // Sample the coverage
        end
    endtask
endclass

import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(counter_scoreboard)

    uvm_analysis_imp #(counter_seq_item, counter_scoreboard) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void write(counter_seq_item item);
        static logic [3:0] expected_count = 0;
        if (item.enable)
            expected_count = expected_count + 1;
        if (item.count !== expected_count)
            `uvm_error("SCOREBOARD", $sformatf("Mismatch: Expected %0h, Got %0h", expected_count, item.count))
    endfunction
endclass
          
import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_agent extends uvm_agent;
    `uvm_component_utils(counter_agent)

    counter_driver driver;
    counter_monitor monitor;
    uvm_sequencer #(counter_seq_item) sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        driver = counter_driver::type_id::create("driver", this);
        monitor = counter_monitor::type_id::create("monitor", this);
        sequencer = uvm_sequencer #(counter_seq_item)::type_id::create("sequencer", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
      
import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_env extends uvm_env;
    `uvm_component_utils(counter_env)

    counter_agent agent;
    counter_scoreboard scoreboard;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = counter_agent::type_id::create("agent", this);
        scoreboard = counter_scoreboard::type_id::create("scoreboard", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        agent.monitor.ap.connect(scoreboard.ap);
    endfunction
endclass
      
import uvm_pkg::*;
`include "uvm_macros.svh"
class counter_test extends uvm_test;
    `uvm_component_utils(counter_test)

    counter_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = counter_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        counter_sequence seq;
        phase.raise_objection(this);
        seq = counter_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask

    // Add a report_phase to print coverage
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (env.agent.monitor != null) begin
            `uvm_info("COVERAGE", $sformatf("Coverage: %.2f%%", env.agent.monitor.counter_cg.get_coverage()), UVM_LOW)
        end else begin
            `uvm_error("COVERAGE", "Monitor instance not found!")
        end
    endfunction
endclass
      
import uvm_pkg::*;
`include "uvm_macros.svh"

module counter_tb;
    logic clk;
    logic rst_n;

    // Instantiate the interface
    counter_if vif(clk, rst_n);

    // Instantiate the DUT
    counter dut (
        .clk(vif.clk),
        .rst_n(vif.rst_n),
        .enable(vif.enable),
        .count(vif.count)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 0; // Assert reset (active low)
        #20;       // Hold reset for 20 time units
        rst_n = 1; // De-assert reset
    end

    // UVM test setup
    initial begin
        // Set the virtual interface in the UVM configuration database
        uvm_config_db#(virtual counter_if)::set(null, "*", "vif", vif);
        // Run the test
        run_test("counter_test");
    end
endmodule