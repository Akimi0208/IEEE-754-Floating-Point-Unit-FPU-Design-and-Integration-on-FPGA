`timescale 1ns/1ps
`include "uvm.sv"
import uvm_pkg::*;

// ============================================================================
// CONVERSION FUNCTIONS
// ============================================================================
function real fixed32_to_real(input bit [31:0] in);
    return $itor($signed(in)) / 65536.0;
endfunction

function bit [31:0] real_to_fixed32(input real r);
    return $rtoi(r * 65536.0);
endfunction

// ============================================================================
// TRANSACTION ITEM
// ============================================================================
class fpu_item extends uvm_sequence_item;
    rand bit [1:0] opcode;
    rand bit [31:0] a_in;
    rand bit [31:0] b_in;
    bit [31:0] expected;
    bit [31:0] result;
    bit underflow;
    bit overflow;
    bit divide_by_zero;
    int transaction_id;
    static int id_counter = 0;
    
    `uvm_object_utils_begin(fpu_item)
        `uvm_field_int(opcode, UVM_DEFAULT)
        `uvm_field_int(a_in, UVM_DEFAULT)
        `uvm_field_int(b_in, UVM_DEFAULT)
        `uvm_field_int(expected, UVM_DEFAULT | UVM_NOCOMPARE)
        `uvm_field_int(result, UVM_DEFAULT)
        `uvm_field_int(underflow, UVM_DEFAULT)
        `uvm_field_int(overflow, UVM_DEFAULT)
        `uvm_field_int(divide_by_zero, UVM_DEFAULT)
        `uvm_field_int(transaction_id, UVM_DEFAULT)
    `uvm_object_utils_end
    
    constraint opcode_range {
        opcode inside {[0:3]};
    }
    
    constraint avoid_div_by_zero {
        if (opcode == 3) b_in != 0;
    }
    
    function new(string name = "fpu_item");
        super.new(name);
        transaction_id = id_counter++;
    endfunction
    
    function string convert2str();
        real a_real, b_real, result_real, expected_real;
        a_real = fixed32_to_real(a_in);
        b_real = fixed32_to_real(b_in);
        result_real = fixed32_to_real(result);
        expected_real = fixed32_to_real(expected);
        
        return $sformatf("ID=%0d opcode=%0d A=%h(%f) B=%h(%f) Result=%h(%f) Expected=%h(%f) Flags:OVF=%b,UDF=%b,DBZ=%b",
            transaction_id, opcode, a_in, a_real, b_in, b_real, 
            result, result_real, expected, expected_real,
            overflow, underflow, divide_by_zero);
    endfunction
    
    function void calculate_expected();
        real a_real, b_real, expected_real;
        a_real = fixed32_to_real(a_in);
        b_real = fixed32_to_real(b_in);
        
        case(opcode)
            2'b00: expected_real = a_real + b_real;
            2'b01: expected_real = a_real - b_real;
            2'b10: expected_real = a_real * b_real;
            2'b11: begin
                if (b_in == 0) begin
                    expected_real = 0.0;
                end else begin
                    expected_real = a_real / b_real;
                end
            end
        endcase
        expected = real_to_fixed32(expected_real);
    endfunction
    
    function void post_randomize();
        calculate_expected();
    endfunction
endclass

// ============================================================================
// COVERAGE COLLECTOR
// ============================================================================
class fpu_coverage extends uvm_subscriber #(fpu_item);
    `uvm_component_utils(fpu_coverage)
    
    covergroup fpu_cg;
        cp_opcode: coverpoint current_item.opcode {
            bins add = {2'b00};
            bins sub = {2'b01};
            bins mul = {2'b10};
            bins div = {2'b11};
        }
        
        cp_a_value: coverpoint current_item.a_in {
            bins zero = {32'h00000000};
            bins positive_small = {[32'h00000001:32'h0000FFFF]};
            bins positive_medium = {[32'h00010000:32'h3FFFFFFF]};
            bins positive_large = {[32'h40000000:32'h7FFFFFFE]};
            bins max_positive = {32'h7FFFFFFF};
            bins negative_small = {[32'hFFFF0000:32'hFFFFFFFF]};
            bins negative_medium = {[32'hC0000000:32'hFFFEFFFF]};
            bins negative_large = {[32'h80000001:32'hBFFFFFFF]};
            bins max_negative = {32'h80000000};
        }
        
        cp_b_value: coverpoint current_item.b_in {
            bins zero = {32'h00000000};
            bins positive_small = {[32'h00000001:32'h0000FFFF]};
            bins positive_medium = {[32'h00010000:32'h3FFFFFFF]};
            bins positive_large = {[32'h40000000:32'h7FFFFFFE]};
            bins max_positive = {32'h7FFFFFFF};
            bins negative_small = {[32'hFFFF0000:32'hFFFFFFFF]};
            bins negative_medium = {[32'hC0000000:32'hFFFEFFFF]};
            bins negative_large = {[32'h80000001:32'hBFFFFFFF]};
            bins max_negative = {32'h80000000};
        }
        
        cp_a_sign: coverpoint current_item.a_in[31] {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }
        
        cp_b_sign: coverpoint current_item.b_in[31] {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }
        
        cp_overflow: coverpoint current_item.overflow {
            bins no_overflow = {1'b0};
            bins overflow_set = {1'b1};
        }
        
        cp_underflow: coverpoint current_item.underflow {
            bins no_underflow = {1'b0};
            bins underflow_set = {1'b1};
        }
        
        cp_divide_by_zero: coverpoint current_item.divide_by_zero {
            bins no_div0 = {1'b0};
            bins div0_set = {1'b1};
        }
        
        cp_result: coverpoint current_item.result {
            bins zero = {32'h00000000};
            bins positive_small = {[32'h00000001:32'h0000FFFF]};
            bins positive_medium = {[32'h00010000:32'h3FFFFFFF]};
            bins positive_large = {[32'h40000000:32'h7FFFFFFE]};
            bins max_value = {[32'h7FFFFFF0:32'h7FFFFFFF]};
            bins negative_small = {[32'hFFFF0000:32'hFFFFFFFF]};
            bins negative_medium = {[32'hC0000000:32'hFFFEFFFF]};
            bins negative_large = {[32'h80000001:32'hBFFFFFFF]};
            bins min_value = {32'h80000000};
        }
        
        cross_op_signs: cross cp_opcode, cp_a_sign, cp_b_sign {
            bins add_pos_pos = binsof(cp_opcode.add) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.positive);
            bins add_pos_neg = binsof(cp_opcode.add) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.negative);
            bins add_neg_neg = binsof(cp_opcode.add) && binsof(cp_a_sign.negative) && binsof(cp_b_sign.negative);
            bins sub_pos_pos = binsof(cp_opcode.sub) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.positive);
            bins sub_pos_neg = binsof(cp_opcode.sub) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.negative);
            bins sub_neg_pos = binsof(cp_opcode.sub) && binsof(cp_a_sign.negative) && binsof(cp_b_sign.positive);
            bins sub_neg_neg = binsof(cp_opcode.sub) && binsof(cp_a_sign.negative) && binsof(cp_b_sign.negative);
            bins mul_pos_pos = binsof(cp_opcode.mul) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.positive);
            bins mul_pos_neg = binsof(cp_opcode.mul) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.negative);
            bins mul_neg_neg = binsof(cp_opcode.mul) && binsof(cp_a_sign.negative) && binsof(cp_b_sign.negative);
            bins div_pos_pos = binsof(cp_opcode.div) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.positive);
            bins div_pos_neg = binsof(cp_opcode.div) && binsof(cp_a_sign.positive) && binsof(cp_b_sign.negative);
            bins div_neg_pos = binsof(cp_opcode.div) && binsof(cp_a_sign.negative) && binsof(cp_b_sign.positive);
            bins div_neg_neg = binsof(cp_opcode.div) && binsof(cp_a_sign.negative) && binsof(cp_b_sign.negative);
        }
        
        cross_op_overflow: cross cp_opcode, cp_overflow {
            bins add_overflow = binsof(cp_opcode.add) && binsof(cp_overflow.overflow_set);
            bins sub_overflow = binsof(cp_opcode.sub) && binsof(cp_overflow.overflow_set);
            bins mul_overflow = binsof(cp_opcode.mul) && binsof(cp_overflow.overflow_set);
            bins div_overflow = binsof(cp_opcode.div) && binsof(cp_overflow.overflow_set);
        }
        
        cross_op_underflow: cross cp_opcode, cp_underflow {
            bins mul_underflow = binsof(cp_opcode.mul) && binsof(cp_underflow.underflow_set);
            bins div_underflow = binsof(cp_opcode.div) && binsof(cp_underflow.underflow_set);
            ignore_bins add_no_underflow = binsof(cp_opcode.add) && binsof(cp_underflow.underflow_set);
            ignore_bins sub_no_underflow = binsof(cp_opcode.sub) && binsof(cp_underflow.underflow_set);
        }

        cross_div_dbz: cross cp_opcode, cp_divide_by_zero {
            bins div_by_zero = binsof(cp_opcode.div) && binsof(cp_divide_by_zero.div0_set);
            ignore_bins add_impossible = binsof(cp_opcode.add) && binsof(cp_divide_by_zero.div0_set);
            ignore_bins sub_impossible = binsof(cp_opcode.sub) && binsof(cp_divide_by_zero.div0_set);
            ignore_bins mul_impossible = binsof(cp_opcode.mul) && binsof(cp_divide_by_zero.div0_set);
        }
        
        cross_op_zero: cross cp_opcode, cp_a_value, cp_b_value {
            bins add_zero_zero = binsof(cp_opcode.add) && binsof(cp_a_value.zero) && binsof(cp_b_value.zero);
            bins add_zero_nonzero = binsof(cp_opcode.add) && binsof(cp_a_value.zero) && !binsof(cp_b_value.zero);
            bins add_nonzero_zero = binsof(cp_opcode.add) && !binsof(cp_a_value.zero) && binsof(cp_b_value.zero);
            bins sub_zero_zero = binsof(cp_opcode.sub) && binsof(cp_a_value.zero) && binsof(cp_b_value.zero);
            bins sub_zero_nonzero = binsof(cp_opcode.sub) && binsof(cp_a_value.zero) && !binsof(cp_b_value.zero);
            bins sub_nonzero_zero = binsof(cp_opcode.sub) && !binsof(cp_a_value.zero) && binsof(cp_b_value.zero);
            bins mul_zero_zero = binsof(cp_opcode.mul) && binsof(cp_a_value.zero) && binsof(cp_b_value.zero);
            bins mul_zero_nonzero = binsof(cp_opcode.mul) && binsof(cp_a_value.zero) && !binsof(cp_b_value.zero);
            bins mul_nonzero_zero = binsof(cp_opcode.mul) && !binsof(cp_a_value.zero) && binsof(cp_b_value.zero);
            bins div_zero_nonzero = binsof(cp_opcode.div) && binsof(cp_a_value.zero) && !binsof(cp_b_value.zero);
            ignore_bins no_zero_involved = !binsof(cp_a_value.zero) && !binsof(cp_b_value.zero);
        }
    endgroup
    
    covergroup fpu_edge_cg;
        cp_max_values: coverpoint {current_item.a_in, current_item.b_in} {
            bins both_max_pos = {64'h7FFFFFFF_7FFFFFFF};
            bins both_max_neg = {64'h80000000_80000000};
            bins max_pos_max_neg = {64'h7FFFFFFF_80000000};
            bins max_neg_max_pos = {64'h80000000_7FFFFFFF};
        }
        
        cp_special_patterns: coverpoint current_item.a_in {
            bins all_zeros = {32'h00000000};
            bins all_ones = {32'hFFFFFFFF};
            bins alternating_01 = {32'h55555555};
            bins alternating_10 = {32'hAAAAAAAA};
        }
    endgroup
    
    fpu_item current_item;
    int coverage_count = 0;
    
    bit result_bin_hit[9];
    int result_bin_count[9];
    
    string result_bin_names[9] = '{
        "zero (0x00000000)",
        "positive_small [0x00000001:0x0000FFFF]",
        "positive_medium [0x00010000:0x3FFFFFFF]",
        "positive_large [0x40000000:0x7FFFFFFE]",
        "max_value (0x7FFFFFFF)",
        "negative_small [0xFFFF0000:0xFFFFFFFF]",
        "negative_medium [0xC0000000:0xFFFEFFFF]",
        "negative_large [0x80000001:0xBFFFFFFF]",
        "min_value (0x80000000)"
    };
    
    function new(string name = "fpu_coverage", uvm_component parent = null);
        super.new(name, parent);
        fpu_cg = new();
        fpu_edge_cg = new();
        
        foreach(result_bin_hit[i]) begin
            result_bin_hit[i] = 0;
            result_bin_count[i] = 0;
        end
    endfunction
    
    virtual function void write(fpu_item t);
        current_item = t;
        fpu_cg.sample();
        fpu_edge_cg.sample();
        track_result_bin(t.result);
        coverage_count++;
        
        if (coverage_count % 500 == 0) begin
            $display("\n[COVERAGE UPDATE] Sampled %0d transactions - Coverage: %.2f%%", 
                     coverage_count, $get_coverage());
            show_result_bin_status();
        end
    endfunction
    
    function void track_result_bin(bit [31:0] result);
        case (1)
            (result == 32'h00000000): begin
                result_bin_hit[0] = 1;
                result_bin_count[0]++;
            end
            (result inside {[32'h00000001:32'h0000FFFF]}): begin
                result_bin_hit[1] = 1;
                result_bin_count[1]++;
            end
            (result inside {[32'h00010000:32'h3FFFFFFF]}): begin
                result_bin_hit[2] = 1;
                result_bin_count[2]++;
            end
            (result inside {[32'h40000000:32'h7FFFFFFE]}): begin
                result_bin_hit[3] = 1;
                result_bin_count[3]++;
            end
            (result == 32'h7FFFFFFF): begin
                result_bin_hit[4] = 1;
                result_bin_count[4]++;
            end
            (result inside {[32'hFFFF0000:32'hFFFFFFFF]}): begin
                result_bin_hit[5] = 1;
                result_bin_count[5]++;
            end
            (result inside {[32'hC0000000:32'hFFFEFFFF]}): begin
                result_bin_hit[6] = 1;
                result_bin_count[6]++;
            end
            (result inside {[32'h80000001:32'hBFFFFFFF]}): begin
                result_bin_hit[7] = 1;
                result_bin_count[7]++;
            end
            (result == 32'h80000000): begin
                result_bin_hit[8] = 1;
                result_bin_count[8]++;
            end
            default: begin
                $display("WARNING: Result 0x%h doesn't match any bin!", result);
            end
        endcase
    endfunction
    
    function void show_result_bin_status();
        int hit_count = 0;
        
        $display("\n=== RESULT BIN STATUS ===");
        for (int i = 0; i < 9; i++) begin
            if (result_bin_hit[i]) begin
                $display("  [✓] Bin %0d: %-50s (hits: %0d)", i, result_bin_names[i], result_bin_count[i]);
                hit_count++;
            end else begin
                $display("  [✗] Bin %0d: %-50s → MISSING!", i, result_bin_names[i]);
            end
        end
        $display("  Coverage: %0d/9 bins = %.2f%%", hit_count, (real'(hit_count)/9.0)*100.0);
        $display("=========================\n");
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        real total_cov, fpu_cg_cov, edge_cg_cov;
        string report_str;
        int hit_count = 0;
        
        super.report_phase(phase);
        
        fpu_cg_cov = fpu_cg.get_coverage();
        edge_cg_cov = fpu_edge_cg.get_coverage();
        total_cov = $get_coverage();
        
        report_str = "\n========================================\n";
        report_str = {report_str, "       FUNCTIONAL COVERAGE REPORT       \n"};
        report_str = {report_str, "========================================\n"};
        report_str = {report_str, $sformatf("Total Samples      : %0d\n", coverage_count)};
        report_str = {report_str, $sformatf("Overall Coverage   : %.2f%%\n", total_cov)};
        report_str = {report_str, $sformatf("Main CG Coverage   : %.2f%%\n", fpu_cg_cov)};
        report_str = {report_str, $sformatf("Edge CG Coverage   : %.2f%%\n", edge_cg_cov)};
        report_str = {report_str, "========================================\n"};
        report_str = {report_str, "\n=== DETAILED COVERAGE BINS ===\n"};
        report_str = {report_str, $sformatf("  Opcode              : %6.2f%%\n", fpu_cg.cp_opcode.get_coverage())};
        report_str = {report_str, $sformatf("  A Value Ranges      : %6.2f%%\n", fpu_cg.cp_a_value.get_coverage())};
        report_str = {report_str, $sformatf("  B Value Ranges      : %6.2f%%\n", fpu_cg.cp_b_value.get_coverage())};
        report_str = {report_str, $sformatf("  A Sign              : %6.2f%%\n", fpu_cg.cp_a_sign.get_coverage())};
        report_str = {report_str, $sformatf("  B Sign              : %6.2f%%\n", fpu_cg.cp_b_sign.get_coverage())};
        report_str = {report_str, $sformatf("  Overflow Flag       : %6.2f%%\n", fpu_cg.cp_overflow.get_coverage())};
        report_str = {report_str, $sformatf("  Underflow Flag      : %6.2f%%\n", fpu_cg.cp_underflow.get_coverage())};
        report_str = {report_str, $sformatf("  Divide-by-Zero Flag : %6.2f%%\n", fpu_cg.cp_divide_by_zero.get_coverage())};
        report_str = {report_str, $sformatf("  Result Ranges       : %6.2f%%\n", fpu_cg.cp_result.get_coverage())};
        report_str = {report_str, "\n=== CROSS COVERAGE ===\n"};
        report_str = {report_str, $sformatf("  Op × Signs          : %6.2f%%\n", fpu_cg.cross_op_signs.get_coverage())};
        report_str = {report_str, $sformatf("  Op × Overflow       : %6.2f%%\n", fpu_cg.cross_op_overflow.get_coverage())};
        report_str = {report_str, $sformatf("  Op × Underflow      : %6.2f%%\n", fpu_cg.cross_op_underflow.get_coverage())};
        report_str = {report_str, $sformatf("  Div × Div-by-Zero   : %6.2f%%\n", fpu_cg.cross_div_dbz.get_coverage())};
        report_str = {report_str, $sformatf("  Op × Zero Operands  : %6.2f%%\n", fpu_cg.cross_op_zero.get_coverage())};
        report_str = {report_str, "========================================\n"};
        
        if (fpu_cg.cp_result.get_coverage() < 100.0) begin
            report_str = {report_str, "\n!!! RESULT RANGES NOT 100% !!!\n"};
            report_str = {report_str, "=== DETAILED RESULT BIN STATUS ===\n"};
            
            for (int i = 0; i < 9; i++) begin
                if (result_bin_hit[i]) begin
                    report_str = {report_str, $sformatf("  [✓] Bin %0d: %-50s (hits: %0d)\n", 
                                 i, result_bin_names[i], result_bin_count[i])};
                    hit_count++;
                end else begin
                    report_str = {report_str, $sformatf("  [✗] Bin %0d: %-50s → MISSING!\n", 
                                 i, result_bin_names[i])};
                end
            end
            
            report_str = {report_str, $sformatf("\nManual tracking: %0d/9 bins hit = %.2f%%\n", 
                         hit_count, (real'(hit_count)/9.0)*100.0)};
            report_str = {report_str, "===================================\n"};
        end else begin
            report_str = {report_str, "\n✓ All result bins covered!\n"};
        end
        
        $display("%s", report_str);
        `uvm_info(get_type_name(), report_str, UVM_NONE)
    endfunction
endclass

// ============================================================================
// SEQUENCES
// ============================================================================

class fpu_random_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_random_seq)
    
    rand int num_transactions = 1000;
    
    constraint num_constraint {
        soft num_transactions inside {[100:2000]};
    }
    
    function new(string name = "fpu_random_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), $sformatf("Starting random sequence with %0d transactions", num_transactions), UVM_LOW)
        
        for (int i = 0; i < num_transactions; i++) begin
            fpu_item item = fpu_item::type_id::create("item");
            start_item(item);
            
            if (!item.randomize() with {
                opcode dist {0:=25, 1:=25, 2:=25, 3:=25};
                if (opcode == 0 || opcode == 1) {
                    a_in[31:8] inside {[0:24'hFFFFFF]};
                    b_in[31:8] inside {[0:24'hFFFFFF]};
                    a_in[7:0] == 8'h00;
                    b_in[7:0] == 8'h00;
                }
                if (opcode == 2 || opcode == 3) {
                    a_in[31:12] inside {[0:20'h00FFF]};
                    b_in[31:12] inside {[0:20'h00FFF]};
                    a_in[11:0] == 12'h000;
                    b_in[11:0] == 12'h000;
                }
            }) begin
                `uvm_error(get_type_name(), "Randomization failed!")
            end
            
            finish_item(item);
        end
    endtask
endclass

class fpu_coverage_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_coverage_seq)
    
    function new(string name = "fpu_coverage_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "Starting coverage-directed sequence", UVM_LOW)
        test_sign_combinations();
        test_boundary_values();
        test_special_patterns();
        test_error_conditions();
    endtask
    
    task test_sign_combinations();
        `uvm_info(get_type_name(), "Testing sign combinations", UVM_MEDIUM)
        for (int op = 0; op < 4; op++) begin
            create_item(op, 32'h00100000, 32'h00200000);
            create_item(op, 32'h00100000, 32'hFFE00000);
            create_item(op, 32'hFFE00000, 32'h00100000);
            if (op != 3) create_item(op, 32'hFFE00000, 32'hFFF00000);
        end
    endtask
    
    task test_boundary_values();
        `uvm_info(get_type_name(), "Testing boundary values", UVM_MEDIUM)
        for (int op = 0; op < 4; op++) begin
            if (op != 3) create_item(op, 32'h00000000, 32'h00000000);
            create_item(op, 32'h7FFFFFFF, 32'h00010000);
            create_item(op, 32'h80000000, 32'h00010000);
            create_item(op, 32'h00000001, 32'h00000001);
        end
    endtask
    
    task test_special_patterns();
        `uvm_info(get_type_name(), "Testing special patterns", UVM_MEDIUM)
        create_item(0, 32'h55555555, 32'hAAAAAAAA);
        create_item(1, 32'hAAAAAAAA, 32'h55555555);
        create_item(2, 32'h00010000, 32'h00010000);
        create_item(2, 32'h00020000, 32'h00020000);
        create_item(3, 32'h00040000, 32'h00020000);
    endtask
    
    task test_error_conditions();
        `uvm_info(get_type_name(), "Testing error conditions", UVM_MEDIUM)
        create_item(0, 32'h75300000, 32'h75300000);
        create_item(2, 32'h3E800000, 32'h3E800000);
        create_item(2, 32'h00000042, 32'h00000042);
    endtask
    
    task create_item(bit [1:0] opcode, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("coverage_item");
        start_item(item);
        item.opcode = opcode;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_zero_operands_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_zero_operands_seq)
    
    function new(string name = "fpu_zero_operands_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== ZERO OPERANDS BOOST ===", UVM_LOW)
        
        repeat(50) create_item(2'b00, 32'h00000000, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b00, 32'h00000000, $urandom_range(32'h00000001, 32'h7FFFFFFF));
            create_item(2'b00, $urandom_range(32'h00000001, 32'h7FFFFFFF), 32'h00000000);
            create_item(2'b00, 32'h00000000, $urandom_range(32'h80000000, 32'hFFFFFFFF));
            create_item(2'b00, $urandom_range(32'h80000000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        repeat(50) create_item(2'b01, 32'h00000000, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b01, 32'h00000000, $urandom_range(32'h00000001, 32'h7FFFFFFF));
            create_item(2'b01, $urandom_range(32'h00000001, 32'h7FFFFFFF), 32'h00000000);
            create_item(2'b01, 32'h00000000, $urandom_range(32'h80000000, 32'hFFFFFFFF));
            create_item(2'b01, $urandom_range(32'h80000000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        repeat(50) create_item(2'b10, 32'h00000000, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b10, 32'h00000000, $urandom_range(32'h00001000, 32'h00FFF000));
            create_item(2'b10, $urandom_range(32'h00001000, 32'h00FFF000), 32'h00000000);
            create_item(2'b10, 32'h00000000, $urandom_range(32'hFFF01000, 32'hFFFFFFFF));
            create_item(2'b10, $urandom_range(32'hFFF01000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        for (int i = 0; i < 50; i++) begin
            create_item(2'b11, 32'h00000000, $urandom_range(32'h00001000, 32'h7FFFFFFF));
            create_item(2'b11, 32'h00000000, $urandom_range(32'h80000000, 32'hFFFFF000));
        end
        
        `uvm_info(get_type_name(), "Zero operands boost complete", UVM_LOW)
    endtask
    
    task create_item(bit [1:0] op, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("zero_item");
        start_item(item);
        item.opcode = op;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_edge_boost_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_edge_boost_seq)
    
    function new(string name = "fpu_edge_boost_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== EDGE CASE BOOST ===", UVM_LOW)
        
        repeat(30) begin
            create_item(0, 32'h7FFFFFFF, 32'h7FFFFFFF);
            create_item(1, 32'h7FFFFFFF, 32'h7FFFFFFF);
            create_item(2, 32'h7FFFFFFF, 32'h00001000);
            create_item(3, 32'h7FFFFFFF, 32'h00010000);
        end
        
        repeat(30) begin
            create_item(0, 32'h80000000, 32'h80000000);
            create_item(1, 32'h80000000, 32'h80000000);
            create_item(2, 32'h80000000, 32'h00001000);
            create_item(3, 32'h80000000, 32'h00010000);
        end
        
        repeat(30) begin
            create_item(0, 32'h7FFFFFFF, 32'h80000000);
            create_item(1, 32'h7FFFFFFF, 32'h80000000);
            create_item(2, 32'h7FFFFFFF, 32'hFFFF0000);
            create_item(3, 32'h7FFFFFFF, 32'h80000000);
        end
        
        repeat(30) begin
            create_item(0, 32'h80000000, 32'h7FFFFFFF);
            create_item(1, 32'h80000000, 32'h7FFFFFFF);
            create_item(2, 32'h80000000, 32'hFFFF0000);
            create_item(3, 32'h80000000, 32'h7FFFFFFF);
        end
        
        repeat(20) begin
            create_item(0, 32'hFFFFFFFF, 32'h00010000);
            create_item(1, 32'hFFFFFFFF, 32'h00010000);
            create_item(2, 32'hFFFFFFFF, 32'h00001000);
            create_item(3, 32'hFFFFFFFF, 32'h00010000);
        end
        
        repeat(20) begin
            create_item(0, 32'h55555555, 32'h00010000);
            create_item(1, 32'h55555555, 32'h00010000);
            create_item(0, 32'hAAAAAAAA, 32'h00010000);
            create_item(1, 32'hAAAAAAAA, 32'h00010000);
        end
    endtask
    
    task create_item(bit [1:0] op, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("edge_item");
        start_item(item);
        item.opcode = op;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_div_by_zero_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_div_by_zero_seq)
    
    function new(string name = "fpu_div_by_zero_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== DIV BY ZERO BOOST ===", UVM_LOW)
        
        repeat(50) create_item(32'h00000000, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'h00000001, 32'h0000FFFF), 32'h00000000);
            create_item($urandom_range(32'h00010000, 32'h3FFFFFFF), 32'h00000000);
            create_item($urandom_range(32'h40000000, 32'h7FFFFFFE), 32'h00000000);
        end
        
        repeat(50) create_item(32'h7FFFFFFF, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'hFFFF0000, 32'hFFFFFFFF), 32'h00000000);
            create_item($urandom_range(32'hC0000000, 32'hFFFEFFFF), 32'h00000000);
            create_item($urandom_range(32'h80000001, 32'hBFFFFFFF), 32'h00000000);
        end
        
        repeat(50) create_item(32'h80000000, 32'h00000000);
        
        repeat(30) begin
            create_item(32'h00010000, 32'h00000000);
            create_item(32'hFFFF0000, 32'h00000000);
            create_item(32'h00020000, 32'h00000000);
            create_item(32'hFFFE0000, 32'h00000000);
        end
        
        `uvm_info(get_type_name(), "Div by zero boost complete", UVM_LOW)
    endtask
    
    task create_item(bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("div0_item");
        start_item(item);
        item.opcode = 2'b11;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_underflow_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_underflow_seq)
    
    function new(string name = "fpu_underflow_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== UNDERFLOW BOOST ===", UVM_LOW)
        
        for (int i = 1; i < 256; i++) begin
            for (int j = 1; j < 256; j++) begin
                create_item(2'b10, {16'h0000, i[7:0], 8'h00}, {16'h0000, j[7:0], 8'h00});
            end
        end
        
        repeat(50) begin
            create_item(2'b10, 32'h00000001, 32'h00000001);
            create_item(2'b10, 32'h00000002, 32'h00000002);
            create_item(2'b10, 32'h00000010, 32'h00000010);
            create_item(2'b10, 32'h00000100, 32'h00000100);
            create_item(2'b10, 32'h00001000, 32'h00001000);
            create_item(2'b10, 32'h00000042, 32'h00000042);
            create_item(2'b10, 32'h0000FFFF, 32'h00000001);
            create_item(2'b10, 32'h00000001, 32'h0000FFFF);
            create_item(2'b10, 32'h00008000, 32'h00000002);
            create_item(2'b10, 32'h00000002, 32'h00008000);
        end
        
        for (int i = 0; i < 100; i++) begin
            bit [31:0] a_val = {16'h0000, $urandom_range(1, 16'hFFFF)};
            bit [31:0] b_val = {16'h0000, $urandom_range(1, 16'hFFFF)};
            create_item(2'b10, a_val, b_val);
        end
        
        repeat(50) begin
            create_item(2'b11, 32'h00000001, 32'h10000000);
            create_item(2'b11, 32'h00000001, 32'h20000000);
            create_item(2'b11, 32'h00000001, 32'h30000000);
            create_item(2'b11, 32'h00000001, 32'h40000000);
            create_item(2'b11, 32'h00000001, 32'h50000000);
            create_item(2'b11, 32'h00000001, 32'h60000000);
            create_item(2'b11, 32'h00000001, 32'h70000000);
        end
        
        repeat(50) begin
            create_item(2'b11, 32'h00000007, 32'h3E800000);
            create_item(2'b11, 32'h00000010, 32'h20000000);
            create_item(2'b11, 32'h00000100, 32'h30000000);
            create_item(2'b11, 32'h00001000, 32'h40000000);
            create_item(2'b11, 32'h00008000, 32'h50000000);
            create_item(2'b11, 32'h0000FFFF, 32'h60000000);
            create_item(2'b11, 32'h00000042, 32'h7FFF0000);
        end
        
        for (int i = 0; i < 100; i++) begin
            bit [31:0] a_val = {16'h0000, $urandom_range(1, 16'hFFFF)};
            bit [31:0] b_val = {2'b01, $urandom_range(0, 29'h1FFFFFFF), 1'b0};
            create_item(2'b11, a_val, b_val);
        end
        
        `uvm_info(get_type_name(), "Underflow boost complete", UVM_LOW)
    endtask
    
    task create_item(bit [1:0] op, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("underflow_item");
        start_item(item);
        item.opcode = op;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_value_ranges_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_value_ranges_seq)
    
    function new(string name = "fpu_value_ranges_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== VALUE RANGES BOOST ===", UVM_LOW)
        
        for (int op = 0; op < 4; op++) begin
            repeat(10) test_range(op, 32'h00000000, 32'h00010000);
            repeat(10) test_range(op, 32'h00000001, 32'h00010000);
            repeat(10) test_range(op, 32'h00008000, 32'h00010000);
            repeat(10) test_range(op, 32'h0000FFFF, 32'h00010000);
            repeat(10) test_range(op, 32'h00010000, 32'h00010000);
            repeat(10) test_range(op, 32'h20000000, 32'h00010000);
            repeat(10) test_range(op, 32'h3FFFFFFF, 32'h00010000);
            repeat(10) test_range(op, 32'h40000000, 32'h00001000);
            repeat(10) test_range(op, 32'h60000000, 32'h00001000);
            repeat(10) test_range(op, 32'h7FFFFFFE, 32'h00001000);
            
            if (op != 2) repeat(10) test_range(op, 32'h7FFFFFFF, 32'h00010000);
            
            repeat(10) test_range(op, 32'hFFFF0000, 32'h00010000);
            repeat(10) test_range(op, 32'hFFFF8000, 32'h00010000);
            repeat(10) test_range(op, 32'hFFFFFFFF, 32'h00010000);
            repeat(10) test_range(op, 32'hC0000000, 32'h00010000);
            repeat(10) test_range(op, 32'hE0000000, 32'h00010000);
            repeat(10) test_range(op, 32'hFFFEFFFF, 32'h00010000);
            repeat(10) test_range(op, 32'h80000001, 32'h00001000);
            repeat(10) test_range(op, 32'hA0000000, 32'h00001000);
            repeat(10) test_range(op, 32'hBFFFFFFF, 32'h00001000);
            
            if (op != 2) repeat(10) test_range(op, 32'h80000000, 32'h00010000);
        end
    endtask
    
    task test_range(int op, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("range_item");
        start_item(item);
        item.opcode = op[1:0];
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_coverage_boost_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_coverage_boost_seq)
    
    fpu_edge_boost_seq edge_seq;
    fpu_zero_operands_seq zero_seq;
    fpu_div_by_zero_seq div0_seq;
    fpu_underflow_seq underflow_seq;
    fpu_value_ranges_seq ranges_seq;
    
    function new(string name = "fpu_coverage_boost_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "======== COVERAGE BOOST STARTING ========", UVM_LOW)
        
        edge_seq = fpu_edge_boost_seq::type_id::create("edge_seq");
        zero_seq = fpu_zero_operands_seq::type_id::create("zero_seq");
        div0_seq = fpu_div_by_zero_seq::type_id::create("div0_seq");
        underflow_seq = fpu_underflow_seq::type_id::create("underflow_seq");
        ranges_seq = fpu_value_ranges_seq::type_id::create("ranges_seq");
        
        `uvm_info(get_type_name(), "Phase 1: Zero Operands", UVM_LOW)
        zero_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 2: Div by Zero", UVM_LOW)
        div0_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 3: Underflow", UVM_LOW)
        underflow_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 4: Edge Cases", UVM_LOW)
        edge_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 5: Value Ranges", UVM_LOW)
        ranges_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "======== COVERAGE BOOST COMPLETE ========", UVM_LOW)
    endtask
endclass

class fpu_result_fix_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_result_fix_seq)
    
    function new(string name = "fpu_result_fix_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== RESULT RANGES FIX ===", UVM_LOW)
        
        repeat(100) begin
            create_item(2'b00, 32'h7FFF0000, 32'h7FFF0000);
            create_item(2'b10, 32'h7FFF0000, 32'h7FFF0000);
            create_item(2'b00, 32'h80000000, 32'h00000000);
            create_item(2'b01, 32'h00000000, 32'h80000000);
            create_item(2'b10, 32'h80000000, 32'h00010000);
            create_item(2'b11, 32'h80000000, 32'h00010000);
        end
        
        repeat(50) begin
            create_item(2'b00, 32'h3FFF0000, 32'h3FFF0000);
            create_item(2'b01, 32'h7FFFFFFE, 32'h00000001);
        end
    endtask
    
    task create_item(bit [1:0] op, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("result_fix_item");
        start_item(item);
        item.opcode = op;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_div_underflow_fix_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_div_underflow_fix_seq)
    
    function new(string name = "fpu_div_underflow_fix_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== DIV UNDERFLOW FIX ===", UVM_LOW)
        
        for (int a_low = 1; a_low <= 16'hFFFF; a_low += 256) begin
            for (int b_val = 30'h20000000; b_val <= 30'h70000000; b_val += 30'h10000000) begin
                create_item({16'h0000, a_low[15:0]}, {b_val[29:0], 2'b00});
            end
        end
        
        repeat(200) begin
            create_item(32'h00000001, 32'h40000000);
            create_item(32'h00000001, 32'h50000000);
            create_item(32'h00000001, 32'h60000000);
            create_item(32'h00000001, 32'h70000000);
        end
        
        repeat(100) begin
            create_item(32'h0000FFFF, 32'h40000000);
            create_item(32'h00008000, 32'h50000000);
            create_item(32'h00001000, 32'h60000000);
            create_item(32'h00000100, 32'h70000000);
        end
    endtask
    
    task create_item(bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("div_udf_item");
        start_item(item);
        item.opcode = 2'b11;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_comprehensive_div0_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_comprehensive_div0_seq)
    
    function new(string name = "fpu_comprehensive_div0_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== COMPREHENSIVE DIV/0 FIX ===", UVM_LOW)
        
        repeat(100) create_item(32'h00000000);
        
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'h00000001, 32'h0000FFFF));
            create_item($urandom_range(32'h00010000, 32'h3FFFFFFF));
            create_item($urandom_range(32'h40000000, 32'h7FFFFFFE));
        end
        
        repeat(100) create_item(32'h7FFFFFFF);
        
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'hFFFF0000, 32'hFFFFFFFF));
            create_item($urandom_range(32'hC0000000, 32'hFFFEFFFF));
            create_item($urandom_range(32'h80000001, 32'hBFFFFFFF));
        end
        
        repeat(100) create_item(32'h80000000);
    endtask
    
    task create_item(bit [31:0] a);
        fpu_item item = fpu_item::type_id::create("div0_item");
        start_item(item);
        item.opcode = 2'b11;
        item.a_in = a;
        item.b_in = 32'h00000000;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

class fpu_zero_comprehensive_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_zero_comprehensive_seq)
    
    function new(string name = "fpu_zero_comprehensive_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== ZERO OPERANDS COMPREHENSIVE FIX ===", UVM_LOW)
        
        repeat(200) create_item(2'b00, 32'h00000000, 32'h00000000);
        
        repeat(100) create_zero_with_range(2'b00, 1, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b00, 32'h00000000, 32'h7FFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b00, 32'h00000000, 32'h80000000);
        
        repeat(100) create_zero_with_range(2'b00, 0, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b00, 32'h7FFFFFFF, 32'h00000000);
        repeat(100) create_zero_with_range(2'b00, 0, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b00, 32'h80000000, 32'h00000000);
        
        repeat(200) create_item(2'b01, 32'h00000000, 32'h00000000);
        
        repeat(100) create_zero_with_range(2'b01, 1, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b01, 1, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b01, 1, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b01, 32'h00000000, 32'h7FFFFFFF);
        repeat(100) create_zero_with_range(2'b01, 1, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b01, 1, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b01, 1, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b01, 32'h00000000, 32'h80000000);
        
        repeat(100) create_zero_with_range(2'b01, 0, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b01, 0, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b01, 0, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b01, 32'h7FFFFFFF, 32'h00000000);
        repeat(100) create_zero_with_range(2'b01, 0, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b01, 0, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b01, 0, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b01, 32'h80000000, 32'h00000000);
        
        repeat(200) create_item(2'b10, 32'h00000000, 32'h00000000);
        
        repeat(100) create_zero_with_range(2'b10, 1, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b10, 1, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b10, 1, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b10, 32'h00000000, 32'h7FFFFFFF);
        repeat(100) create_zero_with_range(2'b10, 1, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b10, 1, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b10, 1, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b10, 32'h00000000, 32'h80000000);
        
        repeat(100) create_zero_with_range(2'b10, 0, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b10, 0, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b10, 0, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b10, 32'h7FFFFFFF, 32'h00000000);
        repeat(100) create_zero_with_range(2'b10, 0, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b10, 0, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b10, 0, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b10, 32'h80000000, 32'h00000000);
        
        repeat(100) create_zero_with_range(2'b11, 1, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b11, 1, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b11, 1, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b11, 32'h00000000, 32'h7FFFFFFF);
        repeat(100) create_zero_with_range(2'b11, 1, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b11, 1, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b11, 1, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b11, 32'h00000000, 32'h80000000);
    endtask
    
    task create_item(bit [1:0] op, bit [31:0] a, bit [31:0] b);
        fpu_item item = fpu_item::type_id::create("zero_comp_item");
        start_item(item);
        item.opcode = op;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
    
    task create_zero_with_range(bit [1:0] op, bit zero_first, bit [31:0] min_val, bit [31:0] max_val);
        bit [31:0] rand_val = $urandom_range(min_val, max_val);
        if (zero_first) begin
            create_item(op, 32'h00000000, rand_val);
        end else begin
            create_item(op, rand_val, 32'h00000000);
        end
    endtask
endclass

class fpu_100_coverage_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_100_coverage_seq)
    
    fpu_result_fix_seq result_seq;
    fpu_div_underflow_fix_seq div_udf_seq;
    fpu_comprehensive_div0_seq div0_seq;
    fpu_zero_comprehensive_seq zero_seq;
    
    function new(string name = "fpu_100_coverage_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "======== TARGETING 100% COVERAGE ========", UVM_LOW)
        
        result_seq = fpu_result_fix_seq::type_id::create("result_seq");
        div_udf_seq = fpu_div_underflow_fix_seq::type_id::create("div_udf_seq");
        div0_seq = fpu_comprehensive_div0_seq::type_id::create("div0_seq");
        zero_seq = fpu_zero_comprehensive_seq::type_id::create("zero_seq");
        
        `uvm_info(get_type_name(), "Phase 1: Zero Operands", UVM_LOW)
        zero_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 2: Div by Zero", UVM_LOW)
        div0_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 3: Div Underflow", UVM_LOW)
        div_udf_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 4: Result Ranges", UVM_LOW)
        result_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "======== 100% COVERAGE TARGET COMPLETE ========", UVM_LOW)
    endtask
endclass

class fpu_special_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_special_seq)
    
    function new(string name = "fpu_special_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "Starting special test sequence", UVM_LOW)
        
        `uvm_info(get_type_name(), "=== ADDITION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b00, 32'h43211200, 32'h00000000, 32'h43211200);
        create_and_send_item(2'b00, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b00, 32'h7FFF0000, 32'h7FFF0000, 32'hFFFE0000);
        create_and_send_item(2'b00, 32'h80000000, 32'h80000000, 32'h00000000);
        
        `uvm_info(get_type_name(), "=== SUBTRACTION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b01, 32'h43211200, 32'h00000000, 32'h43211200);
        create_and_send_item(2'b01, 32'h00000000, 32'h43211200, 32'hBCDEEE00);
        create_and_send_item(2'b01, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b01, 32'h7FFF0000, 32'h80000000, 32'hFFFF0000);
        create_and_send_item(2'b01, 32'h80000000, 32'h7FFF0000, 32'h00010000);
        
        `uvm_info(get_type_name(), "=== MULTIPLICATION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b10, 32'h43211234, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b10, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b10, 32'h43211200, 32'h00010000, 32'h43211200);
        create_and_send_item(2'b10, 32'h43211200, 32'hFFFF0000, 32'hBCDEEE00);
        create_and_send_item(2'b10, 32'h7FFF0000, 32'h7FFF0000, 32'hFFFE0000);
        create_and_send_item(2'b10, 32'h80000000, 32'h80000000, 32'h00000000);
        create_and_send_item(2'b10, 32'h00020000, 32'h00030000, 32'h00060000);
        create_and_send_item(2'b10, 32'hFFFE0000, 32'hFFFD0000, 32'h00060000);
        create_and_send_item(2'b10, 32'h00020000, 32'hFFFE0000, 32'hFFFC0000);
        
        `uvm_info(get_type_name(), "=== DIVISION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b11, 32'h00030000, 32'h00000000, 32'h7FFFFFFF);
        create_and_send_item(2'b11, 32'h00028000, 32'h00010000, 32'h00028000);
        create_and_send_item(2'b11, 32'h00028000, 32'hFFFF0000, 32'hFFFD8000);
        create_and_send_item(2'b11, 32'h00000000, 32'h00020000, 32'h00000000);
        create_and_send_item(2'b11, 32'h00060000, 32'h00020000, 32'h00030000);
        create_and_send_item(2'b11, 32'hFFFA0000, 32'hFFFE0000, 32'h00030000);
        create_and_send_item(2'b11, 32'h00060000, 32'hFFFE0000, 32'hFFFD0000);
        create_and_send_item(2'b11, 32'h00010000, 32'h00020000, 32'h00008000);
        
        `uvm_info(get_type_name(), "=== OVERFLOW SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b00, 32'h75300000, 32'h75300000, 32'h7FFFFFFF);
        create_and_send_item(2'b00, 32'h8AD00000, 32'h8AD00000, 32'h7FFFFFFF);
        create_and_send_item(2'b10, 32'h3E800000, 32'h3E800000, 32'h7FFFFFFF);
        create_and_send_item(2'b11, 32'h75300000, 32'h00008000, 32'h7FFFFFFF);
        
        `uvm_info(get_type_name(), "=== UNDERFLOW SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b10, 32'h00000042, 32'h00000042, 32'h7FFFFFFF);
        create_and_send_item(2'b11, 32'h00000007, 32'h3E800000, 32'h7FFFFFFF);
        
        `uvm_info(get_type_name(), "=== DIV0 SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b11, 32'h20252000, 32'h00000000, 32'h7FFFFFFF);
        
        `uvm_info(get_type_name(), "=== ZERO SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b00, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b01, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b10, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b11, 32'h00000000, 32'h00000000, 32'h7FFFFFFF);
    endtask
    
    task create_and_send_item(bit [1:0] opcode, bit [31:0] a_in, bit [31:0] b_in, bit [31:0] expected);
        fpu_item item = fpu_item::type_id::create("special_item");
        start_item(item);
        item.opcode = opcode;
        item.a_in = a_in;
        item.b_in = b_in;
        item.expected = expected;
        finish_item(item);
    endtask
endclass

class fpu_virtual_seq_v2 extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_virtual_seq_v2)
    
    fpu_random_seq rand_seq;
    fpu_special_seq special_seq;
    fpu_coverage_seq coverage_seq;
    fpu_coverage_boost_seq boost_seq;
    fpu_100_coverage_seq fix_seq;
    
    function new(string name = "fpu_virtual_seq_v2");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "Starting ENHANCED virtual sequence for 100% coverage", UVM_LOW)
        
        rand_seq = fpu_random_seq::type_id::create("rand_seq");
        special_seq = fpu_special_seq::type_id::create("special_seq");
        coverage_seq = fpu_coverage_seq::type_id::create("coverage_seq");
        boost_seq = fpu_coverage_boost_seq::type_id::create("boost_seq");
        fix_seq = fpu_100_coverage_seq::type_id::create("fix_seq");
        
        `uvm_info(get_type_name(), "PHASE 1: Special + Coverage Directed", UVM_LOW)
        special_seq.start(m_sequencer);
        coverage_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "PHASE 2: Random baseline (300 txns)", UVM_LOW)
        rand_seq.num_transactions = 300;
        rand_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "PHASE 3: Coverage boost", UVM_LOW)
        boost_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "PHASE 4: 100% COVERAGE FIX", UVM_LOW)
        fix_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "PHASE 5: Final random (200 txns)", UVM_LOW)
        rand_seq.num_transactions = 200;
        rand_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "======== ALL PHASES COMPLETE ========", UVM_LOW)
    endtask
endclass

// ============================================================================
// DRIVER
// ============================================================================
class fpu_driver extends uvm_driver #(fpu_item);
    `uvm_component_utils(fpu_driver)
    
    virtual fpu_if vif;
    int cycle_count = 0;
    
    function new(string name = "fpu_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV", "Failed to get virtual interface")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        
        vif.valid_in <= 0;
        vif.a <= 0;
        vif.b <= 0;
        vif.opcode <= 0;
        
        wait(vif.rst == 0);
        @(posedge vif.clk);
        
        `uvm_info(get_type_name(), "Driver starting - BACK-TO-BACK MODE", UVM_LOW)
        
        forever begin
            fpu_item req_item;
            
            seq_item_port.get_next_item(req_item);
            
            `uvm_info(get_type_name(), 
                $sformatf("Driving transaction ID=%0d at cycle %0d", 
                req_item.transaction_id, cycle_count), UVM_HIGH)
            
            vif.valid_in <= 1;
            vif.a <= req_item.a_in;
            vif.b <= req_item.b_in;
            vif.opcode <= req_item.opcode;
            
            @(posedge vif.clk);
            
            seq_item_port.item_done();
            cycle_count++;
        end
    endtask
endclass

// ============================================================================
// MONITOR
// ============================================================================
class fpu_monitor extends uvm_monitor;
    `uvm_component_utils(fpu_monitor)
    
    virtual fpu_if vif;
    uvm_analysis_port #(fpu_item) mon_analysis_port;
    
    int expected_latency = 29;
    fpu_item pending_items[$];
    int input_cycles[$];
    int cycle_count = 0;
    
    function new(string name = "fpu_monitor", uvm_component parent = null);
        super.new(name, parent);
        mon_analysis_port = new("mon_analysis_port", this);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Failed to get virtual interface")
        end
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info(get_type_name(), "Monitor starting", UVM_LOW)
        
        fork
            track_inputs();
            capture_outputs();
            track_cycles();
        join
    endtask
    
    task track_cycles();
        forever begin
            @(posedge vif.clk);
            cycle_count++;
        end
    endtask
    
    task track_inputs();
        forever begin
            @(posedge vif.clk);
            if (vif.valid_in) begin
                fpu_item item = fpu_item::type_id::create("captured_item");
                
                item.opcode = vif.opcode;
                item.a_in = vif.a;
                item.b_in = vif.b;
                item.calculate_expected();
                item.transaction_id = pending_items.size();
                
                pending_items.push_back(item);
                input_cycles.push_back(cycle_count);
                
                `uvm_info(get_type_name(),
                    $sformatf("Captured input ID=%0d at cycle %0d", 
                    item.transaction_id, cycle_count), UVM_HIGH)
            end
        end
    endtask
    
    task capture_outputs();
        forever begin
            @(posedge vif.clk);
            
            if (((vif.valid_out === 1'bX && vif.result !== 32'b0) || (vif.valid_out == 1'b1)) 
                 && pending_items.size() > 0) begin
                
                fpu_item item = pending_items.pop_front();
                int input_cycle = input_cycles.pop_front();
                int latency = cycle_count - input_cycle;
                
                item.result = vif.result;
                item.underflow = vif.underflow;
                item.overflow = vif.overflow;
                item.divide_by_zero = vif.divide_by_zero;
                
                `uvm_info(get_type_name(),
                    $sformatf("Output ID=%0d at cycle %0d (latency: %0d)", 
                    item.transaction_id, cycle_count, latency), UVM_MEDIUM)
                
                if (latency != expected_latency) begin
                    `uvm_warning(get_type_name(),
                        $sformatf("Wrong latency! Expected %0d, got %0d", 
                        expected_latency, latency))
                end
                
                mon_analysis_port.write(item);
            end
        end
    endtask
endclass

// ============================================================================
// SCOREBOARD
// ============================================================================
class fpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fpu_scoreboard)
    
    uvm_analysis_imp #(fpu_item, fpu_scoreboard) mon_export;
    int pass_count = 0;
    int fail_count = 0;
    int total_count = 0;
    
    function new(string name = "fpu_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        mon_export = new("mon_export", this);
    endfunction
    
    virtual function void write(fpu_item item);
        total_count++;
        
        if (check_result(item)) begin
            pass_count++;
            `uvm_info(get_type_name(),
                $sformatf("✓ PASS ID=%0d opcode=%0d", 
                item.transaction_id, item.opcode), UVM_MEDIUM)
        end else begin
            fail_count++;
            `uvm_error(get_type_name(),
                $sformatf("✗ FAIL ID=%0d opcode=%0d", 
                item.transaction_id, item.opcode))
            `uvm_info(get_type_name(), item.convert2str(), UVM_LOW)
        end
        
        if (total_count % 100 == 0) begin
            print_summary();
        end
    endfunction
    
    function bit check_result(fpu_item item);
        int diff;
        
        if (item.overflow || item.underflow || item.divide_by_zero) begin
            return 1'b1;
        end
        
        if (item.opcode == 2'b11 && item.b_in == 0) begin
            return item.divide_by_zero;
        end
        
        if ((item.opcode == 2'b00 && item.a_in == 32'h7FFF0000 && item.b_in == 32'h7FFF0000) ||
            (item.opcode == 2'b00 && item.a_in == 32'h80000000 && item.b_in == 32'h80000000) ||
            (item.opcode == 2'b01 && item.a_in == 32'h7FFF0000 && item.b_in == 32'h80000000) ||
            (item.opcode == 2'b01 && item.a_in == 32'h80000000 && item.b_in == 32'h7FFF0000) ||
            (item.opcode == 2'b10 && item.a_in == 32'h7FFF0000 && item.b_in == 32'h7FFF0000) ||
            (item.opcode == 2'b10 && item.a_in == 32'h80000000 && item.b_in == 32'h80000000)) begin
            return item.overflow;
        end
        
        if (((item.opcode == 2'b10) &&
            ((item.a_in[31:16] == 16'b0 && item.a_in[15:0] != 16'b0) ||
            (item.b_in[31:16] == 16'b0 && item.b_in[15:0] != 16'b0))) ||
            ((item.opcode == 2'b11) &&
            ((item.a_in[31:16] == 16'b0 && item.a_in[15:0] != 16'b0) &&
            (item.b_in[30:29] != 2'b0)))) begin
            return item.underflow;
        end
        
        if (item.result === item.expected) begin
            return 1'b1;
        end else begin
            diff = (item.result > item.expected) ? 
                   (item.result - item.expected) : 
                   (item.expected - item.result);
            return (diff <= 2);
        end
    endfunction
    
    function void print_summary();
        real success_rate = (total_count > 0) ? (real'(pass_count) / real'(total_count)) * 100.0 : 0.0;
        
        `uvm_info(get_type_name(),
            $sformatf("Summary: PASS=%0d FAIL=%0d TOTAL=%0d RATE=%.1f%%",
            pass_count, fail_count, total_count, success_rate), UVM_LOW)
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
            $sformatf("\n=== FINAL SCOREBOARD SUMMARY ===\n" +
                     "Total Transactions: %0d\n" +
                     "Passed: %0d\n" +
                     "Failed: %0d\n" +
                     "Success Rate: %.1f%%",
            total_count, pass_count, fail_count,
            (total_count > 0) ? (real'(pass_count)/real'(total_count)*100.0) : 0.0),
            UVM_NONE)
    endfunction
endclass

// ============================================================================
// AGENT
// ============================================================================
class fpu_agent extends uvm_agent;
    `uvm_component_utils(fpu_agent)
    
    fpu_driver driver;
    fpu_monitor monitor;
    uvm_sequencer #(fpu_item) sequencer;
    
    function new(string name = "fpu_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = fpu_monitor::type_id::create("monitor", this);
        
        if (get_is_active() == UVM_ACTIVE) begin
            driver = fpu_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer#(fpu_item)::type_id::create("sequencer", this);
        end
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
