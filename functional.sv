import uvm_pkg::*;
`include "uvm_macros.svh"

class counter_monitor extends uvm_monitor;
    `uvm_component_utils(counter_monitor)

    virtual counter_if vif;
    uvm_analysis_port #(counter_seq_item) ap;

    // Functional coverage group
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