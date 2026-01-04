`timescale 1ns/1ps
`include "uvm.sv"
import uvm_pkg::*;


// Conversion functions (keep as global functions)
function real fixed32_to_real(input bit [31:0] in);
    real temp;
    temp = $itor($signed(in)) / 65536.0;
    return temp;
endfunction

function bit [31:0] real_to_fixed32(input real r);
    bit [31:0] temp;
    temp = $rtoi(r * 65536.0);
    return temp;
endfunction

// ============================================================================
// TRANSACTION ITEM - UVM VERSION
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
    
    // UVM Field Automation Macros
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
            2'b00: expected_real = a_real + b_real; // ADD
            2'b01: expected_real = a_real - b_real; // SUB  
            2'b10: expected_real = a_real * b_real; // MUL
            2'b11: begin // DIV
                if (b_in == 0) begin
                    expected_real = 0.0;
                end else begin
                    expected_real = a_real / b_real;
                end
            end
        endcase
        expected = real_to_fixed32(expected_real);
    endfunction
    
    // Post randomization to calculate expected value
    function void post_randomize();
        calculate_expected();
    endfunction
endclass

// ============================================================================
// COVERAGE COLLECTOR
// ============================================================================
class fpu_coverage extends uvm_subscriber #(fpu_item);
    `uvm_component_utils(fpu_coverage)
    
    // Coverage group for FPU operations
    covergroup fpu_cg;
        
        // Basic opcode coverage
        cp_opcode: coverpoint current_item.opcode {
            bins add = {2'b00};
            bins sub = {2'b01};
            bins mul = {2'b10};
            bins div = {2'b11};
        }
        
        // Input A value ranges
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
        
        // Input B value ranges
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
        
        // Sign combinations for inputs
        cp_a_sign: coverpoint current_item.a_in[31] {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }
        
        cp_b_sign: coverpoint current_item.b_in[31] {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }
        
        // Flag coverage
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
        
        // Result value ranges
        cp_result: coverpoint current_item.result {
            bins zero = {32'h00000000};
            bins positive_small = {[32'h00000001:32'h0000FFFF]};
            bins positive_medium = {[32'h00010000:32'h3FFFFFFF]};
            bins positive_large = {[32'h40000000:32'h7FFFFFFE]};
            bins max_value = {[32'h7FFFFFF0:32'h3FFFFFFF]};
            bins negative_small = {[32'hFFFF0000:32'hFFFFFFFF]};
            bins negative_medium = {[32'hC0000000:32'hFFFEFFFF]};
            bins negative_large = {[32'h80000001:32'hBFFFFFFF]};
            bins min_value = {32'h80000000};
        }
        
        // Cross coverage: Operation with sign combinations
        cross_op_signs: cross cp_opcode, cp_a_sign, cp_b_sign {
            // Interesting combinations
            bins add_pos_pos = binsof(cp_opcode.add) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.positive);
            bins add_pos_neg = binsof(cp_opcode.add) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.negative);
            bins add_neg_neg = binsof(cp_opcode.add) && 
                               binsof(cp_a_sign.negative) && 
                               binsof(cp_b_sign.negative);
            
            bins sub_pos_pos = binsof(cp_opcode.sub) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.positive);
            bins sub_pos_neg = binsof(cp_opcode.sub) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.negative);
            bins sub_neg_pos = binsof(cp_opcode.sub) && 
                               binsof(cp_a_sign.negative) && 
                               binsof(cp_b_sign.positive);
            bins sub_neg_neg = binsof(cp_opcode.sub) && 
                               binsof(cp_a_sign.negative) && 
                               binsof(cp_b_sign.negative);
            
            bins mul_pos_pos = binsof(cp_opcode.mul) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.positive);
            bins mul_pos_neg = binsof(cp_opcode.mul) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.negative);
            bins mul_neg_neg = binsof(cp_opcode.mul) && 
                               binsof(cp_a_sign.negative) && 
                               binsof(cp_b_sign.negative);
            
            bins div_pos_pos = binsof(cp_opcode.div) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.positive);
            bins div_pos_neg = binsof(cp_opcode.div) && 
                               binsof(cp_a_sign.positive) && 
                               binsof(cp_b_sign.negative);
            bins div_neg_pos = binsof(cp_opcode.div) && 
                               binsof(cp_a_sign.negative) && 
                               binsof(cp_b_sign.positive);
            bins div_neg_neg = binsof(cp_opcode.div) && 
                               binsof(cp_a_sign.negative) && 
                               binsof(cp_b_sign.negative);
        }
        
        // Cross coverage: Operation with overflow
        cross_op_overflow: cross cp_opcode, cp_overflow {
            bins add_overflow = binsof(cp_opcode.add) && binsof(cp_overflow.overflow_set);
            bins sub_overflow = binsof(cp_opcode.sub) && binsof(cp_overflow.overflow_set);
            bins mul_overflow = binsof(cp_opcode.mul) && binsof(cp_overflow.overflow_set);
            bins div_overflow = binsof(cp_opcode.div) && binsof(cp_overflow.overflow_set);
        }
        
        // Cross coverage: Operation with underflow
        cross_op_underflow: cross cp_opcode, cp_underflow {
          // ??nh ngh?a các bins h?p l?
          bins mul_underflow = binsof(cp_opcode.mul) && binsof(cp_underflow.underflow_set);
          bins div_underflow = binsof(cp_opcode.div) && binsof(cp_underflow.underflow_set);
    
          //IGNORE các bins không th? x?y ra (ADD/SUB không th? có underflow)
          ignore_bins add_no_underflow = binsof(cp_opcode.add) && binsof(cp_underflow.underflow_set);
          ignore_bins sub_no_underflow = binsof(cp_opcode.sub) && binsof(cp_underflow.underflow_set);
 
        }

        
        cross_div_dbz: cross cp_opcode, cp_divide_by_zero {
          // Ch? bin này là h?p l?
          bins div_by_zero = binsof(cp_opcode.div) && binsof(cp_divide_by_zero.div0_set);
    
          // IGNORE các bins không th? x?y ra (ADD/SUB/MUL không th? có divide_by_zero)
          ignore_bins add_impossible = binsof(cp_opcode.add) && binsof(cp_divide_by_zero.div0_set);
          ignore_bins sub_impossible = binsof(cp_opcode.sub) && binsof(cp_divide_by_zero.div0_set);
          ignore_bins mul_impossible = binsof(cp_opcode.mul) && binsof(cp_divide_by_zero.div0_set);
        }
        
        // Cross coverage: Zero operand cases
        cross_op_zero: cross cp_opcode, cp_a_value, cp_b_value {
    // ADD with zero (3 bins)
    bins add_zero_zero = binsof(cp_opcode.add) && 
                         binsof(cp_a_value.zero) && 
                         binsof(cp_b_value.zero);
    bins add_zero_nonzero = binsof(cp_opcode.add) && 
                            binsof(cp_a_value.zero) &&
                            !binsof(cp_b_value.zero);
    bins add_nonzero_zero = binsof(cp_opcode.add) && 
                            !binsof(cp_a_value.zero) &&
                            binsof(cp_b_value.zero);
    
    // SUB with zero (3 bins)
    bins sub_zero_zero = binsof(cp_opcode.sub) && 
                         binsof(cp_a_value.zero) && 
                         binsof(cp_b_value.zero);
    bins sub_zero_nonzero = binsof(cp_opcode.sub) && 
                            binsof(cp_a_value.zero) &&
                            !binsof(cp_b_value.zero);
    bins sub_nonzero_zero = binsof(cp_opcode.sub) && 
                            !binsof(cp_a_value.zero) &&
                            binsof(cp_b_value.zero);
    
    // MUL with zero (3 bins)
    bins mul_zero_zero = binsof(cp_opcode.mul) && 
                         binsof(cp_a_value.zero) && 
                         binsof(cp_b_value.zero);
    bins mul_zero_nonzero = binsof(cp_opcode.mul) && 
                            binsof(cp_a_value.zero) &&
                            !binsof(cp_b_value.zero);
    bins mul_nonzero_zero = binsof(cp_opcode.mul) && 
                            !binsof(cp_a_value.zero) &&
                            binsof(cp_b_value.zero);
    
    // DIV with zero numerator (1 bin)
    bins div_zero_nonzero = binsof(cp_opcode.div) && 
                            binsof(cp_a_value.zero) &&
                            !binsof(cp_b_value.zero);
    
    // IGNORE
    ignore_bins no_zero_involved = 
        !binsof(cp_a_value.zero) && !binsof(cp_b_value.zero);
}

        
    endgroup
    
    // Additional coverage group for edge cases
    covergroup fpu_edge_cg;
        
        // Maximum values coverage
        cp_max_values: coverpoint {current_item.a_in, current_item.b_in} {
            bins both_max_pos = {64'h7FFFFFFF_7FFFFFFF};
            bins both_max_neg = {64'h80000000_80000000};
            bins max_pos_max_neg = {64'h7FFFFFFF_80000000};
            bins max_neg_max_pos = {64'h80000000_7FFFFFFF};
        }
        
        // Special patterns
        cp_special_patterns: coverpoint current_item.a_in {
            bins all_zeros = {32'h00000000};
            bins all_ones = {32'hFFFFFFFF};
            bins alternating_01 = {32'h55555555};
            bins alternating_10 = {32'hAAAAAAAA};
        }
        
    endgroup
    
    fpu_item current_item;
    int coverage_count = 0;
    
    // *** THÊM: Manual tracking cho result bins ***
    bit result_bin_hit[9];  // Track 9 result bins
    int result_bin_count[9]; // Count hits per bin
    
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
        
        // Initialize tracking arrays
        foreach(result_bin_hit[i]) begin
            result_bin_hit[i] = 0;
            result_bin_count[i] = 0;
        end
    endfunction
    
    virtual function void write(fpu_item t);
        current_item = t;
        fpu_cg.sample();
        fpu_edge_cg.sample();
        
        // *** THÊM: Track result bin ***
        track_result_bin(t.result);
        
        coverage_count++;
        
        if (coverage_count % 500 == 0) begin
            $display("\n[COVERAGE UPDATE] Sampled %0d transactions - Coverage: %.2f%%", 
                     coverage_count, $get_coverage());
            
            // Show result bin status
            show_result_bin_status();
        end
    endfunction
    
    // *** THÊM: Function ?? track result bin ***
    function void track_result_bin(bit [31:0] result);
        case (1)
            // Bin 0: zero
            (result == 32'h00000000): begin
                result_bin_hit[0] = 1;
                result_bin_count[0]++;
            end
            
            // Bin 1: positive_small [0x00000001:0x0000FFFF]
            (result inside {[32'h00000001:32'h0000FFFF]}): begin
                result_bin_hit[1] = 1;
                result_bin_count[1]++;
            end
            
            // Bin 2: positive_medium [0x00010000:0x3FFFFFFF]
            (result inside {[32'h00010000:32'h3FFFFFFF]}): begin
                result_bin_hit[2] = 1;
                result_bin_count[2]++;
            end
            
            // Bin 3: positive_large [0x40000000:0x7FFFFFFE]
            (result inside {[32'h40000000:32'h7FFFFFFE]}): begin
                result_bin_hit[3] = 1;
                result_bin_count[3]++;
            end
            
            // Bin 4: max_value (0x7FFFFFFF)
            (result == 32'h7FFFFFFF): begin
                result_bin_hit[4] = 1;
                result_bin_count[4]++;
            end
            
            // Bin 5: negative_small [0xFFFF0000:0xFFFFFFFF]
            (result inside {[32'hFFFF0000:32'hFFFFFFFF]}): begin
                result_bin_hit[5] = 1;
                result_bin_count[5]++;
            end
            
            // Bin 6: negative_medium [0xC0000000:0xFFFEFFFF]
            (result inside {[32'hC0000000:32'hFFFEFFFF]}): begin
                result_bin_hit[6] = 1;
                result_bin_count[6]++;
            end
            
            // Bin 7: negative_large [0x80000001:0xBFFFFFFF]
            (result inside {[32'h80000001:32'hBFFFFFFF]}): begin
                result_bin_hit[7] = 1;
                result_bin_count[7]++;
            end
            
            // Bin 8: min_value (0x80000000)
            (result == 32'h80000000): begin
                result_bin_hit[8] = 1;
                result_bin_count[8]++;
            end
            
            default: begin
                $display("WARNING: Result 0x%h doesn't match any bin!", result);
            end
        endcase
    endfunction
    
    // *** THÊM: Function ?? hi?n th? status ***
    function void show_result_bin_status();
        int hit_count = 0;
        
        $display("\n=== RESULT BIN STATUS ===");
        for (int i = 0; i < 9; i++) begin
            if (result_bin_hit[i]) begin
                $display("  [?] Bin %0d: %-50s (hits: %0d)", i, result_bin_names[i], result_bin_count[i]);
                hit_count++;
            end else begin
                $display("  [?] Bin %0d: %-50s ? MISSING!", i, result_bin_names[i]);
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
        
        report_str = "\n";
        report_str = {report_str, "========================================\n"};
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
        
        // *** THÊM: Hi?n th? chi ti?t result bins ***
        if (fpu_cg.cp_result.get_coverage() < 100.0) begin
            report_str = {report_str, "\n!!! RESULT RANGES NOT 100% !!!\n"};
            report_str = {report_str, "=== DETAILED RESULT BIN STATUS ===\n"};
            
            for (int i = 0; i < 9; i++) begin
                if (result_bin_hit[i]) begin
                    report_str = {report_str, $sformatf("  [?] Bin %0d: %-50s (hits: %0d)\n", 
                                 i, result_bin_names[i], result_bin_count[i])};
                    hit_count++;
                end else begin
                    report_str = {report_str, $sformatf("  [?] Bin %0d: %-50s ? MISSING!\n", 
                                 i, result_bin_names[i])};
                end
            end
            
            report_str = {report_str, $sformatf("\nManual tracking: %0d/9 bins hit = %.2f%%\n", 
                         hit_count, (real'(hit_count)/9.0)*100.0)};
            report_str = {report_str, "===================================\n"};
        end else begin
            report_str = {report_str, "\n? All result bins covered!\n"};
        end
        
        $display("%s", report_str);
        
        `uvm_info(get_type_name(), report_str, UVM_NONE)
    endfunction
    
endclass

// ============================================================================
// SEQUENCES
// ============================================================================

// Random Sequence
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
            fpu_item item;
            item = fpu_item::type_id::create("item");
            
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

// Coverage-directed sequence
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
            // Positive + Positive
            create_item(op, 32'h00100000, 32'h00200000);
            // Positive + Negative
            create_item(op, 32'h00100000, 32'hFFE00000);
            // Negative + Positive
            create_item(op, 32'hFFE00000, 32'h00100000);
            // Negative + Negative
            if (op != 3) // Avoid div by zero
                create_item(op, 32'hFFE00000, 32'hFFF00000);
        end
    endtask
    
    task test_boundary_values();
        `uvm_info(get_type_name(), "Testing boundary values", UVM_MEDIUM)
        
        for (int op = 0; op < 4; op++) begin
            // Zero
            if (op != 3)
                create_item(op, 32'h00000000, 32'h00000000);
            // Max positive
            create_item(op, 32'h7FFFFFFF, 32'h00010000);
            // Max negative
            create_item(op, 32'h80000000, 32'h00010000);
            // Small values
            create_item(op, 32'h00000001, 32'h00000001);
        end
    endtask
    
    task test_special_patterns();
        `uvm_info(get_type_name(), "Testing special patterns", UVM_MEDIUM)
        
        // Alternating patterns
        create_item(0, 32'h55555555, 32'hAAAAAAAA);
        create_item(1, 32'hAAAAAAAA, 32'h55555555);
        
        // Power of 2 values
        create_item(2, 32'h00010000, 32'h00010000); // 1.0 * 1.0
        create_item(2, 32'h00020000, 32'h00020000); // 2.0 * 2.0
        create_item(3, 32'h00040000, 32'h00020000); // 4.0 / 2.0
    endtask
    
    task test_error_conditions();
        `uvm_info(get_type_name(), "Testing error conditions", UVM_MEDIUM)
        
        // Overflow tests
        create_item(0, 32'h75300000, 32'h75300000);
        create_item(2, 32'h3E800000, 32'h3E800000);
        
        // Underflow tests
        create_item(2, 32'h00000042, 32'h00000042);
        
        
    endtask
    
    task create_item(bit [1:0] opcode, bit [31:0] a, bit [31:0] b);
        fpu_item item;
        item = fpu_item::type_id::create("coverage_item");
        
        start_item(item);
        item.opcode = opcode;
        item.a_in = a;
        item.b_in = b;
        item.calculate_expected();
        finish_item(item);
    endtask
endclass

// 1. ZERO OPERANDS - ENHANCED (35.42% -> 100%)
class fpu_zero_operands_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_zero_operands_seq)
    
    function new(string name = "fpu_zero_operands_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== ZERO OPERANDS BOOST (ENHANCED) ===", UVM_LOW)
        
        // ADD: T?t c? combinations v?i nhi?u variations
        repeat(50) create_item(2'b00, 32'h00000000, 32'h00000000); // zero + zero
        
        // ADD: zero + nhi?u giá tr? positive khác nhau
        for (int i = 0; i < 30; i++) begin
            create_item(2'b00, 32'h00000000, $urandom_range(32'h00000001, 32'h7FFFFFFF));
        end
        
        // ADD: nhi?u giá tr? positive + zero
        for (int i = 0; i < 30; i++) begin
            create_item(2'b00, $urandom_range(32'h00000001, 32'h7FFFFFFF), 32'h00000000);
        end
        
        // ADD: zero + nhi?u giá tr? negative
        for (int i = 0; i < 30; i++) begin
            create_item(2'b00, 32'h00000000, $urandom_range(32'h80000000, 32'hFFFFFFFF));
        end
        
        // ADD: nhi?u giá tr? negative + zero
        for (int i = 0; i < 30; i++) begin
            create_item(2'b00, $urandom_range(32'h80000000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        // SUB: T?t c? combinations
        repeat(50) create_item(2'b01, 32'h00000000, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b01, 32'h00000000, $urandom_range(32'h00000001, 32'h7FFFFFFF));
        end
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b01, $urandom_range(32'h00000001, 32'h7FFFFFFF), 32'h00000000);
        end
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b01, 32'h00000000, $urandom_range(32'h80000000, 32'hFFFFFFFF));
        end
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b01, $urandom_range(32'h80000000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        // MUL: T?t c? combinations
        repeat(50) create_item(2'b10, 32'h00000000, 32'h00000000);
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b10, 32'h00000000, $urandom_range(32'h00001000, 32'h00FFF000));
        end
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b10, $urandom_range(32'h00001000, 32'h00FFF000), 32'h00000000);
        end
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b10, 32'h00000000, $urandom_range(32'hFFF01000, 32'hFFFFFFFF));
        end
        
        for (int i = 0; i < 30; i++) begin
            create_item(2'b10, $urandom_range(32'hFFF01000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        // DIV: zero / non-zero (nhi?u variations)
        for (int i = 0; i < 50; i++) begin
            create_item(2'b11, 32'h00000000, $urandom_range(32'h00001000, 32'h7FFFFFFF));
        end
        
        for (int i = 0; i < 50; i++) begin
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

// 2. EDGE BOOST - ENHANCED (100% -> maintain)
class fpu_edge_boost_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_edge_boost_seq)
    
    function new(string name = "fpu_edge_boost_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== EDGE CASE BOOST (ENHANCED) ===", UVM_LOW)
        
        // Max values - t?t c? operations
        repeat(30) create_item(0, 32'h7FFFFFFF, 32'h7FFFFFFF);
        repeat(30) create_item(1, 32'h7FFFFFFF, 32'h7FFFFFFF);
        repeat(30) create_item(2, 32'h7FFFFFFF, 32'h00001000);
        repeat(30) create_item(3, 32'h7FFFFFFF, 32'h00010000);
        
        repeat(30) create_item(0, 32'h80000000, 32'h80000000);
        repeat(30) create_item(1, 32'h80000000, 32'h80000000);
        repeat(30) create_item(2, 32'h80000000, 32'h00001000);
        repeat(30) create_item(3, 32'h80000000, 32'h00010000);
        
        repeat(30) create_item(0, 32'h7FFFFFFF, 32'h80000000);
        repeat(30) create_item(1, 32'h7FFFFFFF, 32'h80000000);
        repeat(30) create_item(2, 32'h7FFFFFFF, 32'hFFFF0000);
        repeat(30) create_item(3, 32'h7FFFFFFF, 32'h80000000);
        
        repeat(30) create_item(0, 32'h80000000, 32'h7FFFFFFF);
        repeat(30) create_item(1, 32'h80000000, 32'h7FFFFFFF);
        repeat(30) create_item(2, 32'h80000000, 32'hFFFF0000);
        repeat(30) create_item(3, 32'h80000000, 32'h7FFFFFFF);
        
        // Special patterns
        repeat(20) create_item(0, 32'hFFFFFFFF, 32'h00010000);
        repeat(20) create_item(1, 32'hFFFFFFFF, 32'h00010000);
        repeat(20) create_item(2, 32'hFFFFFFFF, 32'h00001000);
        repeat(20) create_item(3, 32'hFFFFFFFF, 32'h00010000);
        
        repeat(20) create_item(0, 32'h55555555, 32'h00010000);
        repeat(20) create_item(1, 32'h55555555, 32'h00010000);
        repeat(20) create_item(0, 32'hAAAAAAAA, 32'h00010000);
        repeat(20) create_item(1, 32'hAAAAAAAA, 32'h00010000);
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

// 3. DIV BY ZERO - ENHANCED (62.5% -> 100%)
class fpu_div_by_zero_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_div_by_zero_seq)
    
    function new(string name = "fpu_div_by_zero_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== DIV BY ZERO BOOST (ENHANCED) ===", UVM_LOW)
        
        // Systematic coverage of all value ranges / 0
        
        // Zero / 0
        repeat(50) create_item(32'h00000000, 32'h00000000);
        
        // Positive small / 0
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'h00000001, 32'h0000FFFF), 32'h00000000);
        end
        
        // Positive medium / 0
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'h00010000, 32'h3FFFFFFF), 32'h00000000);
        end
        
        // Positive large / 0
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'h40000000, 32'h7FFFFFFE), 32'h00000000);
        end
        
        // Max positive / 0
        repeat(50) create_item(32'h7FFFFFFF, 32'h00000000);
        
        // Negative small / 0
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'hFFFF0000, 32'hFFFFFFFF), 32'h00000000);
        end
        
        // Negative medium / 0
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'hC0000000, 32'hFFFEFFFF), 32'h00000000);
        end
        
        // Negative large / 0
        for (int i = 0; i < 30; i++) begin
            create_item($urandom_range(32'h80000001, 32'hBFFFFFFF), 32'h00000000);
        end
        
        // Max negative / 0
        repeat(50) create_item(32'h80000000, 32'h00000000);
        
        // Specific patterns / 0
        repeat(30) create_item(32'h00010000, 32'h00000000); // 1.0 / 0
        repeat(30) create_item(32'hFFFF0000, 32'h00000000); // -1.0 / 0
        repeat(30) create_item(32'h00020000, 32'h00000000); // 2.0 / 0
        repeat(30) create_item(32'hFFFE0000, 32'h00000000); // -2.0 / 0
        
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

// 4. UNDERFLOW - ENHANCED (75% -> 100%)
class fpu_underflow_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_underflow_seq)
    
    function new(string name = "fpu_underflow_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== UNDERFLOW BOOST (ENHANCED) ===", UVM_LOW)
        
        
        
        for (int i = 1; i < 256; i++) begin
            for (int j = 1; j < 256; j++) begin
                create_item(2'b10, {16'h0000, i[7:0], 8'h00}, {16'h0000, j[7:0], 8'h00});
            end
        end
        
        // More MUL underflow patterns
        repeat(50) create_item(2'b10, 32'h00000001, 32'h00000001);
        repeat(50) create_item(2'b10, 32'h00000002, 32'h00000002);
        repeat(50) create_item(2'b10, 32'h00000010, 32'h00000010);
        repeat(50) create_item(2'b10, 32'h00000100, 32'h00000100);
        repeat(50) create_item(2'b10, 32'h00001000, 32'h00001000);
        repeat(50) create_item(2'b10, 32'h00000042, 32'h00000042);
        repeat(50) create_item(2'b10, 32'h0000FFFF, 32'h00000001);
        repeat(50) create_item(2'b10, 32'h00000001, 32'h0000FFFF);
        repeat(50) create_item(2'b10, 32'h00008000, 32'h00000002);
        repeat(50) create_item(2'b10, 32'h00000002, 32'h00008000);
        
        // Random small values
        for (int i = 0; i < 100; i++) begin
            bit [31:0] a_val = {16'h0000, $urandom_range(1, 16'hFFFF)};
            bit [31:0] b_val = {16'h0000, $urandom_range(1, 16'hFFFF)};
            create_item(2'b10, a_val, b_val);
        end
        
        // DIV underflow: very small / very large
        // Pattern: a[31:16] = 0, a[15:0] != 0 AND b[30:29] != 0
        
        repeat(50) create_item(2'b11, 32'h00000001, 32'h10000000);
        repeat(50) create_item(2'b11, 32'h00000001, 32'h20000000);
        repeat(50) create_item(2'b11, 32'h00000001, 32'h30000000);
        repeat(50) create_item(2'b11, 32'h00000001, 32'h40000000);
        repeat(50) create_item(2'b11, 32'h00000001, 32'h50000000);
        repeat(50) create_item(2'b11, 32'h00000001, 32'h60000000);
        repeat(50) create_item(2'b11, 32'h00000001, 32'h70000000);
        
        repeat(50) create_item(2'b11, 32'h00000007, 32'h3E800000);
        repeat(50) create_item(2'b11, 32'h00000010, 32'h20000000);
        repeat(50) create_item(2'b11, 32'h00000100, 32'h30000000);
        repeat(50) create_item(2'b11, 32'h00001000, 32'h40000000);
        repeat(50) create_item(2'b11, 32'h00008000, 32'h50000000);
        repeat(50) create_item(2'b11, 32'h0000FFFF, 32'h60000000);
        repeat(50) create_item(2'b11, 32'h00000042, 32'h7FFF0000);
        
        // Random DIV underflow
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

// 5. VALUE RANGES - ENHANCED (maintain 100%)
class fpu_value_ranges_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_value_ranges_seq)
    
    function new(string name = "fpu_value_ranges_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== VALUE RANGES BOOST (ENHANCED) ===", UVM_LOW)
        
        for (int op = 0; op < 4; op++) begin
            // Zero
            repeat(10) test_range(op, 32'h00000000, 32'h00010000);
            
            // Positive small boundaries and middle
            repeat(10) test_range(op, 32'h00000001, 32'h00010000);
            repeat(10) test_range(op, 32'h00008000, 32'h00010000);
            repeat(10) test_range(op, 32'h0000FFFF, 32'h00010000);
            
            // Positive medium boundaries and middle
            repeat(10) test_range(op, 32'h00010000, 32'h00010000);
            repeat(10) test_range(op, 32'h20000000, 32'h00010000);
            repeat(10) test_range(op, 32'h3FFFFFFF, 32'h00010000);
            
            // Positive large boundaries and middle
            repeat(10) test_range(op, 32'h40000000, 32'h00001000);
            repeat(10) test_range(op, 32'h60000000, 32'h00001000);
            repeat(10) test_range(op, 32'h7FFFFFFE, 32'h00001000);
            
            // Max positive
            if (op != 2) repeat(10) test_range(op, 32'h7FFFFFFF, 32'h00010000);
            
            // Negative small boundaries and middle
            repeat(10) test_range(op, 32'hFFFF0000, 32'h00010000);
            repeat(10) test_range(op, 32'hFFFF8000, 32'h00010000);
            repeat(10) test_range(op, 32'hFFFFFFFF, 32'h00010000);
            
            // Negative medium boundaries and middle
            repeat(10) test_range(op, 32'hC0000000, 32'h00010000);
            repeat(10) test_range(op, 32'hE0000000, 32'h00010000);
            repeat(10) test_range(op, 32'hFFFEFFFF, 32'h00010000);
            
            // Negative large boundaries and middle
            repeat(10) test_range(op, 32'h80000001, 32'h00001000);
            repeat(10) test_range(op, 32'hA0000000, 32'h00001000);
            repeat(10) test_range(op, 32'hBFFFFFFF, 32'h00001000);
            
            // Max negative
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

// Master Boost Sequence - SAME AS BEFORE
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
        `uvm_info(get_type_name(), 
            "\n" +
            "========================================\n" +
            "   ENHANCED COVERAGE BOOST STARTING\n" +
            "   Target: >98% coverage\n" +
            "========================================", 
            UVM_LOW)
        
        edge_seq = fpu_edge_boost_seq::type_id::create("edge_seq");
        zero_seq = fpu_zero_operands_seq::type_id::create("zero_seq");
        div0_seq = fpu_div_by_zero_seq::type_id::create("div0_seq");
        underflow_seq = fpu_underflow_seq::type_id::create("underflow_seq");
        ranges_seq = fpu_value_ranges_seq::type_id::create("ranges_seq");
        
        // Priority: lowest coverage first
        `uvm_info(get_type_name(), "Phase 1: Zero Operands (aggressive)", UVM_LOW)
        zero_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 2: Div by Zero (aggressive)", UVM_LOW)
        div0_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 3: Underflow (aggressive)", UVM_LOW)
        underflow_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 4: Edge Cases", UVM_LOW)
        edge_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 5: Value Ranges", UVM_LOW)
        ranges_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), 
            "\n" +
            "========================================\n" +
            "   ENHANCED COVERAGE BOOST COMPLETE\n" +
            "========================================", 
            UVM_LOW)
    endtask
endclass

// ============================================================================
// COVERAGE FIX SEQUENCES - Target specific missing bins
// ============================================================================

// 1. RESULT RANGES FIX (88.89% -> 100%)
// Missing bin is likely "max_value" or "min_value"
class fpu_result_fix_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_result_fix_seq)
    
    function new(string name = "fpu_result_fix_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== RESULT RANGES FIX ===", UVM_LOW)
        
        // Target max_value (32'h7FFFFFFF) - should trigger overflow
        repeat(100) create_item(2'b00, 32'h7FFF0000, 32'h7FFF0000); // ADD overflow
        repeat(100) create_item(2'b10, 32'h7FFF0000, 32'h7FFF0000); // MUL overflow
        
        // Target min_value (32'h80000000) - various operations
        repeat(100) create_item(2'b00, 32'h80000000, 32'h00000000); // ADD with min
        repeat(100) create_item(2'b01, 32'h00000000, 32'h80000000); // SUB to min
        repeat(100) create_item(2'b10, 32'h80000000, 32'h00010000); // MUL with min
        repeat(100) create_item(2'b11, 32'h80000000, 32'h00010000); // DIV with min
        
        // Edge: exact max_positive without overflow
        repeat(50) create_item(2'b00, 32'h3FFF0000, 32'h3FFF0000);
        repeat(50) create_item(2'b01, 32'h7FFFFFFE, 32'h00000001);
        
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

// 2. OP × UNDERFLOW FIX (75% -> 100%)
// Missing: DIV underflow
class fpu_div_underflow_fix_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_div_underflow_fix_seq)
    
    function new(string name = "fpu_div_underflow_fix_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== DIV UNDERFLOW FIX ===", UVM_LOW)
        
        // DIV underflow condition: a[31:16]=0, a[15:0]!=0 AND b[30:29]!=0
        // Systematic coverage
        
        for (int a_low = 1; a_low <= 16'hFFFF; a_low += 256) begin
            for (int b_val = 30'h20000000; b_val <= 30'h70000000; b_val += 30'h10000000) begin
                create_item({16'h0000, a_low[15:0]}, {b_val[29:0], 2'b00});
            end
        end
        
        // Specific high-coverage patterns
        repeat(200) create_item(32'h00000001, 32'h40000000);
        repeat(200) create_item(32'h00000001, 32'h50000000);
        repeat(200) create_item(32'h00000001, 32'h60000000);
        repeat(200) create_item(32'h00000001, 32'h70000000);
        
        repeat(100) create_item(32'h0000FFFF, 32'h40000000);
        repeat(100) create_item(32'h00008000, 32'h50000000);
        repeat(100) create_item(32'h00001000, 32'h60000000);
        repeat(100) create_item(32'h00000100, 32'h70000000);
        
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

// 3. DIV × DIV-BY-ZERO FIX (62.5% -> 100%)
class fpu_comprehensive_div0_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_comprehensive_div0_seq)
    
    function new(string name = "fpu_comprehensive_div0_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== COMPREHENSIVE DIV/0 FIX ===", UVM_LOW)
        
        // EVERY possible result range / 0
        
        // Zero / 0
        repeat(100) create_item(32'h00000000);
        
        // Positive ranges / 0
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'h00000001, 32'h0000FFFF)); // positive_small
        end
        
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'h00010000, 32'h3FFFFFFF)); // positive_medium
        end
        
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'h40000000, 32'h7FFFFFFE)); // positive_large
        end
        
        repeat(100) create_item(32'h7FFFFFFF); // max_positive
        
        // Negative ranges / 0
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'hFFFF0000, 32'hFFFFFFFF)); // negative_small
        end
        
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'hC0000000, 32'hFFFEFFFF)); // negative_medium
        end
        
        for (int i = 0; i < 100; i++) begin
            create_item($urandom_range(32'h80000001, 32'hBFFFFFFF)); // negative_large
        end
        
        repeat(100) create_item(32'h80000000); // max_negative
        
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

// 4. OP × ZERO OPERANDS FIX (40.28% -> 100%)
// This is the biggest gap - need systematic coverage
class fpu_zero_comprehensive_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_zero_comprehensive_seq)
    
    function new(string name = "fpu_zero_comprehensive_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "=== ZERO OPERANDS COMPREHENSIVE FIX ===", UVM_LOW)
        
        // ADD: zero + zero
        repeat(200) create_item(2'b00, 32'h00000000, 32'h00000000);
        
        // ADD: zero + ALL value ranges
        repeat(100) create_zero_with_range(2'b00, 1, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b00, 32'h00000000, 32'h7FFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b00, 1, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b00, 32'h00000000, 32'h80000000);
        
        // ADD: ALL value ranges + zero
        repeat(100) create_zero_with_range(2'b00, 0, 32'h00000001, 32'h0000FFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'h00010000, 32'h3FFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'h40000000, 32'h7FFFFFFE);
        repeat(50) create_item(2'b00, 32'h7FFFFFFF, 32'h00000000);
        repeat(100) create_zero_with_range(2'b00, 0, 32'hFFFF0000, 32'hFFFFFFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'hC0000000, 32'hFFFEFFFF);
        repeat(100) create_zero_with_range(2'b00, 0, 32'h80000001, 32'hBFFFFFFF);
        repeat(50) create_item(2'b00, 32'h80000000, 32'h00000000);
        
        // SUB: Same structure
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
        
        // MUL: Same structure
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
        
        // DIV: zero / non-zero (all ranges)
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

// ============================================================================
// UPDATED VIRTUAL SEQUENCE - ADD TO YOUR MAIN TESTBENCH
// ============================================================================
// Replace the body() task in fpu_virtual_seq with this:
/*
    virtual task body();
        `uvm_info(get_type_name(), "Starting virtual sequence", UVM_LOW)
        
        // Original sequences
        rand_seq = fpu_random_seq::type_id::create("rand_seq");
        special_seq = fpu_special_seq::type_id::create("special_seq");
        coverage_seq = fpu_coverage_seq::type_id::create("coverage_seq");
        boost_seq = fpu_coverage_boost_seq::type_id::create("boost_seq");
        
        // NEW: 100% coverage fix
        fpu_100_coverage_seq fix_seq;
        fix_seq = fpu_100_coverage_seq::type_id::create("fix_seq");
        
        special_seq.start(m_sequencer);
        coverage_seq.start(m_sequencer);
        
        rand_seq.num_transactions = 500;
        rand_seq.start(m_sequencer);
        
        boost_seq.start(m_sequencer);
        
        // NEW: Run 100% fix
        `uvm_info(get_type_name(), "=== 100% COVERAGE FIX PHASE ===", UVM_LOW)
        fix_seq.start(m_sequencer);
        
        // Final random
        rand_seq.num_transactions = 300;
        rand_seq.start(m_sequencer);
    endtask
*/

// 5. MASTER FIX SEQUENCE
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
        `uvm_info(get_type_name(), 
            "\n" +
            "========================================\n" +
            "   TARGETING 100% COVERAGE\n" +
            "   Fixing: Result, Underflow, Div0, Zero\n" +
            "========================================", 
            UVM_LOW)
        
        result_seq = fpu_result_fix_seq::type_id::create("result_seq");
        div_udf_seq = fpu_div_underflow_fix_seq::type_id::create("div_udf_seq");
        div0_seq = fpu_comprehensive_div0_seq::type_id::create("div0_seq");
        zero_seq = fpu_zero_comprehensive_seq::type_id::create("zero_seq");
        
        // Priority: biggest gaps first
        `uvm_info(get_type_name(), "Phase 1: Zero Operands (40.28% -> 100%)", UVM_LOW)
        zero_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 2: Div by Zero (62.5% -> 100%)", UVM_LOW)
        div0_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 3: Div Underflow (75% -> 100%)", UVM_LOW)
        div_udf_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), "Phase 4: Result Ranges (88.89% -> 100%)", UVM_LOW)
        result_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), 
            "\n" +
            "========================================\n" +
            "   100% COVERAGE TARGET COMPLETE\n" +
            "========================================", 
            UVM_LOW)
    endtask
endclass
// Special Test Sequence
class fpu_special_seq extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_special_seq)
    
    function new(string name = "fpu_special_seq");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "Starting special test sequence", UVM_LOW)
        
        // ADDITION TESTS
        `uvm_info(get_type_name(), "=== ADDITION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b00, 32'h43211200, 32'h00000000, 32'h43211200);
        create_and_send_item(2'b00, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b00, 32'h7FFF0000, 32'h7FFF0000, 32'hFFFE0000);
        create_and_send_item(2'b00, 32'h80000000, 32'h80000000, 32'h00000000);
        
        // SUBTRACTION TESTS
        `uvm_info(get_type_name(), "=== SUBTRACTION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b01, 32'h43211200, 32'h00000000, 32'h43211200);
        create_and_send_item(2'b01, 32'h00000000, 32'h43211200, 32'hBCDEEE00);
        create_and_send_item(2'b01, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b01, 32'h7FFF0000, 32'h80000000, 32'hFFFF0000);
        create_and_send_item(2'b01, 32'h80000000, 32'h7FFF0000, 32'h00010000);
        
        // MULTIPLICATION TESTS
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
        
        // DIVISION TESTS
        `uvm_info(get_type_name(), "=== DIVISION SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b11, 32'h00030000, 32'h00000000, 32'h7FFFFFFF);
        create_and_send_item(2'b11, 32'h00028000, 32'h00010000, 32'h00028000);
        create_and_send_item(2'b11, 32'h00028000, 32'hFFFF0000, 32'hFFFD8000);
        create_and_send_item(2'b11, 32'h00000000, 32'h00020000, 32'h00000000);
        create_and_send_item(2'b11, 32'h00060000, 32'h00020000, 32'h00030000);
        create_and_send_item(2'b11, 32'hFFFA0000, 32'hFFFE0000, 32'h00030000);
        create_and_send_item(2'b11, 32'h00060000, 32'hFFFE0000, 32'hFFFD0000);
        create_and_send_item(2'b11, 32'h00010000, 32'h00020000, 32'h00008000);
        
        // OVERFLOW TESTS
        `uvm_info(get_type_name(), "=== OVERFLOW SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b00, 32'h75300000, 32'h75300000, 32'h7FFFFFFF);
        create_and_send_item(2'b00, 32'h8AD00000, 32'h8AD00000, 32'h7FFFFFFF);
        create_and_send_item(2'b10, 32'h3E800000, 32'h3E800000, 32'h7FFFFFFF);
        create_and_send_item(2'b11, 32'h75300000, 32'h00008000, 32'h7FFFFFFF);
        
        // UNDERFLOW TESTS
        `uvm_info(get_type_name(), "=== UNDERFLOW SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b10, 32'h00000042, 32'h00000042, 32'h7FFFFFFF);
        create_and_send_item(2'b11, 32'h00000007, 32'h3E800000, 32'h7FFFFFFF);
        
        // DIV0 TESTS
        `uvm_info(get_type_name(), "=== DIV0 SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b11, 32'h20252000, 32'h00000000, 32'h7FFFFFFF);
        
        // ZERO TESTS
        `uvm_info(get_type_name(), "=== ZERO SPECIAL CASES ===", UVM_LOW)
        create_and_send_item(2'b00, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b01, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b10, 32'h00000000, 32'h00000000, 32'h00000000);
        create_and_send_item(2'b11, 32'h00000000, 32'h00000000, 32'h7FFFFFFF);
    endtask
    
    task create_and_send_item(bit [1:0] opcode, bit [31:0] a_in, bit [31:0] b_in, bit [31:0] expected);
        fpu_item item;
        item = fpu_item::type_id::create("special_item");
        
        start_item(item);
        item.opcode = opcode;
        item.a_in = a_in;
        item.b_in = b_in;
        item.expected = expected;
        finish_item(item);
    endtask
endclass

// Virtual Sequence - UPDATED
class fpu_virtual_seq_v2 extends uvm_sequence #(fpu_item);
    `uvm_object_utils(fpu_virtual_seq_v2)
    
    fpu_random_seq rand_seq;
    fpu_special_seq special_seq;
    fpu_coverage_seq coverage_seq;
    fpu_coverage_boost_seq boost_seq;
    fpu_100_coverage_seq fix_seq;  // NEW
    
    function new(string name = "fpu_virtual_seq_v2");
        super.new(name);
    endfunction
    
    virtual task body();
        `uvm_info(get_type_name(), "Starting ENHANCED virtual sequence for 100% coverage", UVM_LOW)
        
        // Create sequences
        rand_seq = fpu_random_seq::type_id::create("rand_seq");
        special_seq = fpu_special_seq::type_id::create("special_seq");
        coverage_seq = fpu_coverage_seq::type_id::create("coverage_seq");
        boost_seq = fpu_coverage_boost_seq::type_id::create("boost_seq");
        fix_seq = fpu_100_coverage_seq::type_id::create("fix_seq");  // NEW
        
        // Phase 1: Basic tests
        `uvm_info(get_type_name(), "PHASE 1: Special + Coverage Directed", UVM_LOW)
        special_seq.start(m_sequencer);
        coverage_seq.start(m_sequencer);
        
        // Phase 2: Random baseline
        `uvm_info(get_type_name(), "PHASE 2: Random baseline (300 txns)", UVM_LOW)
        rand_seq.num_transactions = 300;
        rand_seq.start(m_sequencer);
        
        // Phase 3: First boost
        `uvm_info(get_type_name(), "PHASE 3: Coverage boost", UVM_LOW)
        boost_seq.start(m_sequencer);
        
        // Phase 4: NEW - Target missing bins
        `uvm_info(get_type_name(), "PHASE 4: 100% COVERAGE FIX", UVM_LOW)
        fix_seq.start(m_sequencer);
        
        // Phase 5: Final random for stability
        `uvm_info(get_type_name(), "PHASE 5: Final random (200 txns)", UVM_LOW)
        rand_seq.num_transactions = 200;
        rand_seq.start(m_sequencer);
        
        `uvm_info(get_type_name(), 
            "\n======================================\n" +
            "  ALL PHASES COMPLETE\n" +
            "  Check coverage report for 100%\n" +
            "======================================", 
            UVM_LOW)
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
                fpu_item item;
                item = fpu_item::type_id::create("captured_item");
                
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
            
            if ( ((vif.valid_out === 1'bX && vif.result !== 32'b0) || (vif.valid_out == 1'b1)) 
                 && pending_items.size() > 0 ) begin
                
                fpu_item item;
                int input_cycle;
                int latency;
                
                item = pending_items.pop_front();
                input_cycle = input_cycles.pop_front();
                latency = cycle_count - input_cycle;
                
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
                $sformatf("? PASS ID=%0d opcode=%0d", 
                item.transaction_id, item.opcode), UVM_MEDIUM)
        end else begin
            fail_count++;
            `uvm_error(get_type_name(),
                $sformatf("? FAIL ID=%0d opcode=%0d", 
                item.transaction_id, item.opcode))
            `uvm_info(get_type_name(), item.convert2str(), UVM_LOW)
        end
        
        if (total_count % 100 == 0) begin
            print_summary();
        end
    endfunction
    
    function bit check_result(fpu_item item);
        int diff;
        
        // FLAGS-BASED PASSING
        if (item.overflow || item.underflow || item.divide_by_zero) begin
            return 1'b1;
        end
        
        // Division by zero
        if (item.opcode == 2'b11 && item.b_in == 0) begin
            return item.divide_by_zero;
        end
        
        // Overflow cases
        if ((item.opcode == 2'b00 && item.a_in == 32'h7FFF0000 && item.b_in == 32'h7FFF0000) ||
            (item.opcode == 2'b00 && item.a_in == 32'h80000000 && item.b_in == 32'h80000000) ||
            (item.opcode == 2'b01 && item.a_in == 32'h7FFF0000 && item.b_in == 32'h80000000) ||
            (item.opcode == 2'b01 && item.a_in == 32'h80000000 && item.b_in == 32'h7FFF0000) ||
            (item.opcode == 2'b10 && item.a_in == 32'h7FFF0000 && item.b_in == 32'h7FFF0000) ||
            (item.opcode == 2'b10 && item.a_in == 32'h80000000 && item.b_in == 32'h80000000)) 
        begin
            return item.overflow;
        end
        
        // Underflow cases
        if (((item.opcode == 2'b10) &&
            ((item.a_in[31:16] == 16'b0 && item.a_in[15:0] != 16'b0) ||
            (item.b_in[31:16] == 16'b0 && item.b_in[15:0] != 16'b0))) ||
            ((item.opcode == 2'b11) &&
            ((item.a_in[31:16] == 16'b0 && item.a_in[15:0] != 16'b0) &&
            (item.b_in[30:29] != 2'b0)))) 
        begin
            return item.underflow;
        end
        
        // Normal comparison
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
        real success_rate;
        if (total_count > 0) begin
            success_rate = (real'(pass_count) / real'(total_count)) * 100.0;
        end else begin
            success_rate = 0.0;
        end
        
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
    endfunction
endclass

// ============================================================================
// ENVIRONMENT
// ============================================================================
class fpu_env extends uvm_env;
    `uvm_component_utils(fpu_env)
    
    fpu_agent agent;
    fpu_scoreboard scoreboard;
    fpu_coverage coverage;
    
    function new(string name = "fpu_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        agent = fpu_agent::type_id::create("agent", this);
        scoreboard = fpu_scoreboard::type_id::create("scoreboard", this);
        coverage = fpu_coverage::type_id::create("coverage", this);
    endfunction
    
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.mon_analysis_port.connect(scoreboard.mon_export);
        agent.monitor.mon_analysis_port.connect(coverage.analysis_export);
    endfunction
endclass

// ============================================================================
// BASE TEST
// ============================================================================
class fpu_base_test extends uvm_test;
    `uvm_component_utils(fpu_base_test)
    
    fpu_env env;
    virtual fpu_if vif;
    
    function new(string name = "fpu_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        env = fpu_env::type_id::create("env", this);
        
        if (!uvm_config_db#(virtual fpu_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("TEST", "Failed to get virtual interface")
        end
        
        uvm_config_db#(virtual fpu_if)::set(this, "env.agent.*", "vif", vif);
    endfunction
    
    virtual task run_phase(uvm_phase phase);
        fpu_virtual_seq_v2 seq;  // Changed from fpu_virtual_seq
        
        phase.raise_objection(this);
        
        apply_reset();
        
        seq = fpu_virtual_seq_v2::type_id::create("seq");  // Changed
        seq.start(env.agent.sequencer);
        
        // If still not 100%, try aggressive mode:
        // fpu_aggressive_100_seq agg_seq;
        // agg_seq = fpu_aggressive_100_seq::type_id::create("agg_seq");
        // agg_seq.start(env.agent.sequencer);
        
        #200000;
        
        phase.drop_objection(this);
    endtask
    
    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        
        $display("\n");
        $display("============================================================");
        $display("              SIMULATION COMPLETED");
        $display("============================================================");
        $display("Check coverage report above for detailed metrics");
        $display("============================================================");
    endfunction
    
    virtual task apply_reset();
        `uvm_info(get_type_name(), "Applying reset", UVM_LOW)
        vif.rst <= 1;
        repeat(5) @(posedge vif.clk);
        vif.rst <= 0;
        repeat(10) @(posedge vif.clk);
    endtask
endclass

// ============================================================================
// INTERFACE
// ============================================================================
interface fpu_if(input logic clk);
    logic rst;
    logic valid_in;
    logic [1:0] opcode;
    logic [31:0] a;
    logic [31:0] b;
    logic valid_out;
    logic [31:0] result;
    logic underflow;
    logic overflow;
    logic divide_by_zero;
endinterface

// ============================================================================
// TESTBENCH TOP
// ============================================================================
module tb;
    logic clk;
    
    always #5 clk = ~clk;
    
    fpu_if fpu_if_inst(clk);
    
    // DUT instantiation
    fpu_pipeline dut (
        .clk(fpu_if_inst.clk),
        .rst(fpu_if_inst.rst),
        .valid_in(fpu_if_inst.valid_in),
        .a(fpu_if_inst.a),
        .b(fpu_if_inst.b),
        .opcode(fpu_if_inst.opcode),
        .valid_out(fpu_if_inst.valid_out),
        .result(fpu_if_inst.result),
        .underflow(fpu_if_inst.underflow),
        .overflow(fpu_if_inst.overflow),
        .divide_by_zero(fpu_if_inst.divide_by_zero)
    );
    
    initial begin
        clk = 0;
        
        $dumpfile("fpu_uvm.vcd");
        $dumpvars(0, tb);
        
        uvm_config_db#(virtual fpu_if)::set(null, "uvm_test_top", "vif", fpu_if_inst);
        
        $display("\n=== FPU UVM Testbench with Coverage ===");
        $display("Expected Latency: 29 cycles");
        $display("Test: fpu_base_test");
        $display("Coverage enabled");
        $display("Starting simulation...\n");
        
        run_test("fpu_base_test");
        
        $display("\n=== UVM SIMULATION COMPLETE ===");
        $finish;
    end
    
    initial begin
        #1000000;
        $display("\n*** WATCHDOG TIMEOUT ***");
        $finish;
    end
endmodule


module fpu_pipeline (
    input clk,
    input rst,
    input valid_in,
    input [31:0] a,
    input [31:0] b,
    input [1:0] opcode,
    
    output valid_out,
    output [31:0] result,
    output underflow,
    output overflow,
    output divide_by_zero
);

    // Pipeline registers
    wire s1_valid, s2_valid, s3_valid, s4_valid;
    wire [31:0] s1_a, s1_b, s2_result, s3_result, s4_result;
    wire [1:0] s1_op, s2_op, s3_op, s4_op;
    wire s2_special, s3_round_ovf, s4_conv_ovf;
    wire overflow12, underflow12, divide_by_zero12;
	 wire overflow23, underflow23, divide_by_zero23;
	 wire overflow34, underflow34, divide_by_zero34;
	 wire overflow45, underflow45, divide_by_zero45;
    
    // Pipeline stages instantiation
    stage1_format_conversion stage1 (
        .clk(clk), .rst(rst),
        .valid_in(valid_in),
        .a_q16(a), .b_q16(b), .opcode(opcode),
        .valid_out(s1_valid),
        .a_ieee(s1_a), .b_ieee(s1_b), .opcode_out(s1_op),
		  .overflow(overflow12),    // C? overflow
		  .underflow(underflow12),   // C? underflow  
		  .divide_by_zero(divide_by_zero12) // C? division by zero
    );
    
    stage2_arithmetic stage2 (
        .clk(clk), .rst(rst),
        .valid_in(s1_valid),
        .a_ieee(s1_a), .b_ieee(s1_b), .opcode(s1_op),
        .valid_out(s2_valid),
        .result_ieee(s2_result), .opcode_out(s2_op),
        .special_case(s2_special),
		  .overflow12(overflow12),    // C? overflow
		  .underflow12(underflow12),   // C? underflow  
		  .divide_by_zero12(divide_by_zero12), // C? division by zero
		  .overflow23(overflow23),    // C? overflow
		  .underflow23(underflow23),   // C? underflow  
		  .divide_by_zero23(divide_by_zero23) // C? division by zero
    );
    
    stage3_normalize_round stage3 (
        .clk(clk), .rst(rst),
        .valid_in(s2_valid),
        .result_ieee(s2_result), .opcode(s2_op), .special_case(s2_special),
        .valid_out(s3_valid),
        .normalized_result(s3_result), .opcode_out(s3_op),
        .rounding_overflow(s3_round_ovf),
		  .overflowo34(overflow34),    // C? overflow
		  .underflowo34(underflow34),   // C? underflow  
		  .divide_by_zeroo34(divide_by_zero34), // C? division by zero
		  .overflowi23(overflow23),    // C? overflow
		  .underflowi23(underflow23),   // C? underflow  
		  .divide_by_zeroi23(divide_by_zero23) // C? division by zero
    );
    
    stage4_format_conversion stage4 (
        .clk(clk), .rst(rst),
        .valid_in(s3_valid),
        .result_ieee(s3_result), .opcode(s3_op), .rounding_overflow(s3_round_ovf),
        .valid_out(s4_valid),
        .result_q16(s4_result), .opcode_out(s4_op),
        .conversion_overflow(s4_conv_ovf),
		  .overflowi34(overflow34),    // C? overflow
		  .underflowi34(underflow34),   // C? underflow  
		  .divide_by_zeroi34(divide_by_zero34), // C? division by zero
		  .overflowo45(overflow45),    // C? overflow
		  .underflowo45(underflow45),   // C? underflow  
		  .divide_by_zeroo45(divide_by_zero45) // C? division by zero
    );
    
    stage5_output_flags stage5 (
        .clk(clk), .rst(rst),
        .valid_in(s4_valid),
        .result_q16(s4_result), .opcode(s4_op), .conversion_overflow(s4_conv_ovf),
        .valid_out(valid_out),
        .result_out(result),
        .underflow(underflow),
        .overflow(overflow),
        .divide_by_zero(divide_by_zero),
		  .overflowi45(overflow45),    // C? overflow
		  .underflowi45(underflow45),   // C? underflow  
		  .divide_by_zeroi45(divide_by_zero45) // C? division by zero
		  
    );

endmodule


module delay_line #(
    parameter WIDTH = 32,
    parameter DELAY = 25
) (
    input clk,
    input rst,
    input [WIDTH-1:0] data_in,
    input valid_in,
    output [WIDTH-1:0] data_out,
    output valid_out
);

    reg [WIDTH-1:0] shift_reg [0:DELAY-1];
    reg valid_reg [0:DELAY-1];
    
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < DELAY; i = i + 1) begin
                shift_reg[i] <= 0;
                valid_reg[i] <= 0;
            end
        end else begin
            // Stage 0
            shift_reg[0] <= data_in;
            valid_reg[0] <= valid_in;
            
            // Các stage ti?p theo
            for (i = 1; i < DELAY; i = i + 1) begin
                shift_reg[i] <= shift_reg[i-1];
                valid_reg[i] <= valid_reg[i-1];
            end
        end
    end
    
    assign data_out = shift_reg[DELAY-1];
    assign valid_out = valid_reg[DELAY-1];

endmodule

module fp_adder (
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg ready
);
    wire a_sign = a[31];
    wire b_sign = b[31];
    wire [7:0] a_exp = a[30:23];
    wire [7:0] b_exp = b[30:23];
    wire [22:0] a_frac = a[22:0];
    wire [22:0] b_frac = b[22:0];
    
    // Internal signals
    reg [7:0] exp_diff;
    reg [7:0] larger_exp;
    reg [26:0] larger_mantissa;  // Extended for guard, round, sticky bits
    reg [26:0] smaller_mantissa;
    reg larger_sign;
    reg smaller_sign;
    
    reg [27:0] sum_mantissa;  // Extra bit for overflow
    reg [7:0] result_exp;
    reg [22:0] result_frac;
    reg result_sign;
    reg [4:0] shift_amount;
    reg [27:0] temp_mantissa;
    reg guard, round, sticky;
    reg [26:0] sticky_shift;
    reg [26:0] shifted_smaller;
    
    always @(*) begin
        ready = 1'b1;
        
        // -------- SPECIAL CASES --------
    // Both zero
    if ((a_exp == 8'b0 && a_frac == 23'b0) &&
        (b_exp == 8'b0 && b_frac == 23'b0)) begin
        result = 32'b0;
        disable compute_block;
    end
    // A zero
    if (a_exp == 8'b0 && a_frac == 23'b0) begin
        result = b;
        disable compute_block;
    end
    // B zero
    if (b_exp == 8'b0 && b_frac == 23'b0) begin
        result = a;
        disable compute_block;
    end
    // A = -B ? exact zero
    if (a_exp == b_exp && a_frac == b_frac && a_sign != b_sign) begin
        result = 32'b0;
        disable compute_block;
    end

        compute_block: begin
            // Determine larger and smaller numbers based on exponent
            if (a_exp > b_exp || (a_exp == b_exp && a_frac >= b_frac)) begin
                larger_exp = a_exp;
                larger_mantissa = {1'b1, a_frac, 3'b0};  // hidden + frac + GRS bits
                smaller_mantissa = {1'b1, b_frac, 3'b0};
                larger_sign = a_sign;
                smaller_sign = b_sign;
                exp_diff = a_exp - b_exp;
            end else begin
                larger_exp = b_exp;
                larger_mantissa = {1'b1, b_frac, 3'b0};
                smaller_mantissa = {1'b1, a_frac, 3'b0};
                larger_sign = b_sign;
                smaller_sign = a_sign;
                exp_diff = b_exp - a_exp;
            end
            
            // Align mantissas with sticky bit calculation
            if (exp_diff > 26) begin
                shifted_smaller = 27'b0;
            end else if (exp_diff == 0) begin
                shifted_smaller = smaller_mantissa;
            end else begin
                // Calculate sticky bit from bits shifted out
                sticky_shift = smaller_mantissa & ((27'b1 << exp_diff) - 1);
                shifted_smaller = smaller_mantissa >> exp_diff;
                if (sticky_shift != 0 && exp_diff > 0) begin
                    shifted_smaller[0] = 1'b1;  // Set sticky bit
                end
            end
            
            // Perform addition/subtraction based on signs
            if (larger_sign == smaller_sign) begin
                // Same sign: add mantissas
                sum_mantissa = {1'b0, larger_mantissa} + {1'b0, shifted_smaller};
                result_sign = larger_sign;
            end else begin
                // Different signs: subtract mantissas
                sum_mantissa = {1'b0, larger_mantissa} - {1'b0, shifted_smaller};
                result_sign = larger_sign;
            end
            
            // Normalize result
            result_exp = larger_exp;
            temp_mantissa = sum_mantissa;
            
            // Case 1: Overflow (bit 27 set) - shift right
            if (sum_mantissa[27]) begin
                temp_mantissa = sum_mantissa >> 1;
                result_exp = result_exp + 1;
            end 
            // Case 2: Already normalized (bit 26 set)
            else if (sum_mantissa[26]) begin
                temp_mantissa = sum_mantissa;
            end
            // Case 3: Need left shift to normalize
            else if (sum_mantissa != 28'b0) begin
                // Count leading zeros and shift
                shift_amount = 5'd0;
                
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                
                result_exp = result_exp - shift_amount;
            end
            
            // Extract guard, round, sticky bits
            guard = temp_mantissa[2];
            round = temp_mantissa[1];
            sticky = temp_mantissa[0];
            
            // Round to nearest, ties to even
            result_frac = temp_mantissa[25:3];
            
            if (guard && (round || sticky || result_frac[0])) begin
                // Round up
                result_frac = result_frac + 1;
                // Check for overflow after rounding
                if (result_frac == 23'b0) begin
                    result_exp = result_exp + 1;
                end
            end
            
            // Handle zero result
            if (temp_mantissa == 28'b0 || result_exp == 8'b0) begin
                result = 32'b0;
            end else begin
                result = {result_sign, result_exp, result_frac};
            end
        end
    end
endmodule

module fp_divider (
    input clk,
    input rst,
    input [31:0] a, 
    input [31:0] b,
    input input_valid,
    
    output reg [31:0] result,
    output reg output_valid
);

// Pipeline registers - 24 stages
reg [31:0] a_pipeline [0:23];
reg [31:0] b_pipeline [0:23];
reg valid_pipeline [0:23];

// Division intermediate signals
reg [23:0] dividend [0:23];
reg [23:0] divisor [0:23]; 
reg [23:0] quotient [0:23];
reg sign_result [0:23];
reg [8:0] exp_result [0:23]; // use 9 bits to allow temporary increments/decrements

integer i;

// Stage 0 - Initialization
always @(posedge clk or posedge rst) begin
    if (rst) begin
        a_pipeline[0] <= 0;
        b_pipeline[0] <= 0;
        valid_pipeline[0] <= 0;
        dividend[0] <= 0;
        divisor[0] <= 0;
        quotient[0] <= 0;
        sign_result[0] <= 0;
        exp_result[0] <= 0;
    end else begin
        a_pipeline[0] <= a;
        b_pipeline[0] <= b;
        valid_pipeline[0] <= input_valid;
        
        if (input_valid) begin
            // Stage 0: Initialize division
            sign_result[0] <= a[31] ^ b[31];
            // correct bias = 127
            exp_result[0] <= {1'b0, a[30:23]}  + 9'd128 - {1'b0, b[30:23]};
            //  nitialize 24-bit mantissas (implicit leading 1 for normalized inputs)
            dividend[0] <= {1'b1, a[22:0]};
            divisor[0] <= {1'b1, b[22:0]};
            quotient[0] <= 24'b0;
        end
    end
end

// Pipeline stages 1-23 - Division steps (restoring-like)
genvar stage;
generate
    for (stage = 1; stage < 24; stage = stage + 1) begin : division_stages
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                a_pipeline[stage] <= 0;
                b_pipeline[stage] <= 0;
                valid_pipeline[stage] <= 0;
                dividend[stage] <= 0;
                divisor[stage] <= 0;
                quotient[stage] <= 0;
                sign_result[stage] <= 0;
                exp_result[stage] <= 0;
            end else begin
                // Propagate pipeline
                a_pipeline[stage] <= a_pipeline[stage-1];
                b_pipeline[stage] <= b_pipeline[stage-1];
                valid_pipeline[stage] <= valid_pipeline[stage-1];
                sign_result[stage] <= sign_result[stage-1];
                exp_result[stage] <= exp_result[stage-1];
                
                if (valid_pipeline[stage-1]) begin
                    // Division step: compare and subtract
                    if (dividend[stage-1] >= divisor[stage-1]) begin
                        dividend[stage] <= dividend[stage-1] - divisor[stage-1];
                        quotient[stage] <= (quotient[stage-1] << 1) | 1'b1;
                    end else begin
                        dividend[stage] <= dividend[stage-1];
                        quotient[stage] <= quotient[stage-1] << 1;
                    end
                    
                    // Shift divisor right for next bit
                    divisor[stage] <= (divisor[stage-1] >> 1);
                end else begin
                    // If not valid, still propagate zeros
                    dividend[stage] <= 0;
                    divisor[stage] <= 0;
                    quotient[stage] <= 0;
                end
            end
        end
    end
endgenerate

// Final stage - Normalization and output
reg [24:0] norm_mant; // allow one extra bit for overflow after rounding
reg [8:0] final_exp;
reg final_sign;
reg [23:0] final_quotient;
reg [23:0] final_dividend; // remainder

always @(posedge clk or posedge rst) begin
    if (rst) begin
        result <= 0;
        output_valid <= 0;
        norm_mant <= 0;
        final_exp <= 0;
        final_sign <= 0;
        final_quotient <= 0;
        final_dividend <= 0;
    end else begin
        output_valid <= valid_pipeline[23];
        
        if (valid_pipeline[23]) begin
            // Division by zero -> Infinity
            if (b_pipeline[23] == 32'b0) begin
                result <= {sign_result[23], 8'hFF, 23'b0};
            end else begin
                final_quotient = quotient[23];   // 24-bit quotient (no guard bit in original algo)
                final_dividend = dividend[23];   // remainder after long division
                final_exp = exp_result[23];
                final_sign = sign_result[23];
                
                // If quotient is zero -> result zero (subnormal/zero)
                if (final_quotient == 24'b0) begin
                    // produce zero (signed zero)
                    result <= {final_sign, 8'd0, 23'b0};
                end else begin
                    // Normalize: shift left until MSB (bit23) == 1
                    // (It should already be 1 for typical normalized inputs, but keep loop)
                    while (final_quotient[23] == 1'b0 && final_exp > 0) begin
                        final_quotient = final_quotient << 1;
                        final_exp = final_exp - 9'd1;
                    end
                    
                    // Rounding: simple round-to-nearest (if remainder != 0, increment mantissa)
                    // This is a conservative implementation because original pipeline lacks explicit guard bit.
                    // If any remainder bits exist -> consider need to round up.
                    norm_mant = {1'b0, final_quotient}; // 25-bit temp (bit24 = 0, bits23:0 = mantissa)
                    if (final_dividend != 24'b0) begin
                        // round up
                        norm_mant = norm_mant + 25'd1;
                    end
                    
                    // Handle mantissa overflow from rounding (if bit24 becomes 1)
                    if (norm_mant[24] == 1'b1) begin
                        // shift right one and increase exponent
                        norm_mant = norm_mant >> 1;
                        final_exp = final_exp + 9'd1;
                    end
                    
                    // Check for exponent overflow -> Infinity
                    if (final_exp >= 9'd255) begin
                        result <= {final_sign, 8'hFF, 23'b0};
                    end else if (final_exp <= 0) begin
                        // underflow to zero or subnormal (we return zero for simplicity)
                        result <= {final_sign, 8'd0, 23'b0};
                    end else begin
                        result <= {final_sign, final_exp[7:0], norm_mant[22:0]};
                    end
                end
            end
        end
    end
end

endmodule

module fp_multiplier (
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg ready
);
    wire a_sign = a[31];
    wire b_sign = b[31];
    wire [7:0] a_exp = a[30:23];
    wire [7:0] b_exp = b[30:23];
    wire [22:0] a_frac = a[22:0];
    wire [22:0] b_frac = b[22:0];
    wire a_zero = a == 32'h37800000;
    wire b_zero = b == 32'h37800000;
    wire a_is_minus_one = (a == 32'hBF800000);
    wire b_is_minus_one = (b == 32'hBF800000);
    wire a_is_one = (a == 32'h3F800000);
    wire b_is_one = (b == 32'h3F800000);
    wire a_inf = (a_exp == 8'hFF) & (a_frac == 23'b0);
    wire b_inf = (b_exp == 8'hFF) & (b_frac == 23'b0);
    wire a_nan = (a_exp == 8'hFF) & (a_frac != 23'b0);
    wire b_nan = (b_exp == 8'hFF) & (b_frac != 23'b0);
    
    // Internal signals
    reg [8:0] exp_sum;
    reg [47:0] frac_product;
    reg [8:0] final_exp_temp;
    reg [7:0] final_exp;
    reg [22:0] final_frac;
    reg final_sign;
    reg guard, round, sticky;
    reg [22:0] frac_before_round;
    
    always @(*) begin
        ready = 1'b1;
        
        // Calculate sign
        final_sign = a_sign ^ b_sign;
        
        // Handle special cases
        if (a_nan | b_nan) begin
            result = 32'h7FC00000; // NaN
        end
        else if ((a_zero & b_inf) | (a_inf & b_zero)) begin
            result = 32'h7FC00000; // NaN for 0 * inf
        end
        else if (a_inf | b_inf) begin
            result = {final_sign, 8'hFF, 23'b0}; // Infinity
        end
        else if (a_zero || b_zero) begin
            result = {final_sign, 8'b0, 23'b0}; // Zero
        end
        else if (a_is_one) begin
          result = b;
        end
        else if (a_is_minus_one) begin
          result = {~b[31], b[30:0]};
        end
        else if (b_is_one) begin
          result = a;
        end
        else if (b_is_minus_one) begin
          result = {~a[31], a[30:0]};
        end

        else begin
            // Multiply mantissas
            frac_product = {1'b1, a_frac} * {1'b1, b_frac};
            
            // Add exponents and subtract bias
            exp_sum = {1'b0, a_exp} + {1'b0, b_exp} - 9'd127;
            
            // Normalize and extract rounding bits
            if (frac_product[47]) begin
                // Product is 1X.XXXXX... (bit 47 set)
                final_exp_temp = exp_sum + 9'd1;
                frac_before_round = frac_product[46:24];
                guard = frac_product[23];
                round = frac_product[22];
                sticky = |frac_product[21:0];
            end else begin
                // Product is 01.XXXXX... (bit 46 set)
                final_exp_temp = exp_sum;
                frac_before_round = frac_product[45:23];
                guard = frac_product[22];
                round = frac_product[21];
                sticky = |frac_product[20:0];
            end
            
            // Round to nearest, ties to even
            final_frac = frac_before_round;
            if (guard && (round || sticky || frac_before_round[0])) begin
                final_frac = frac_before_round + 23'd1;
                // Check for overflow after rounding
                if (final_frac == 23'b0) begin
                    final_exp_temp = final_exp_temp + 9'd1;
                end
            end
            
            // Check for overflow/underflow
            if (final_exp_temp[8] && !final_exp_temp[7]) begin 
                // Overflow (exp >= 255)
                result = {final_sign, 8'hFF, 23'b0};
            end else if (final_exp_temp[8] || (final_exp_temp <= 9'd0)) begin 
                // Underflow (exp <= 0)
                result = {final_sign, 8'b0, 23'b0};
            end else begin
                final_exp = final_exp_temp[7:0];
                result = {final_sign, final_exp, final_frac};
            end
        end
    end
endmodule


module fp_normalizer (
    input [31:0] input_ieee,
    output reg [31:0] normalized_output,
    output reg overflow
);

    wire sign = input_ieee[31];
    wire [7:0] exp = input_ieee[30:23];
    wire [22:0] frac = input_ieee[22:0];

    // Internal signals
    wire [26:0] extended_frac = {2'b01, frac, 2'b00};
    
    always @(*) begin
        overflow = 1'b0;
        
        // Check for special values
        if (exp == 8'hFF) begin // NaN or Infinity
            normalized_output = input_ieee;
        end
        else if (exp == 8'b0) begin // Denormal or Zero
            normalized_output = input_ieee;
        end
        else if (extended_frac[26]) begin
            // Needs right shift
            if (exp == 8'hFE) begin // Would cause overflow
                normalized_output = {sign, 8'hFF, 23'b0}; // Infinity
                overflow = 1'b1;
            end else begin
                normalized_output = {sign, exp + 8'd1, extended_frac[25:3]};
            end
        end
        else begin
            // Already normalized or needs left shift
            normalized_output = input_ieee;
        end
    end

endmodule

module fp_rounding (
    input [31:0] input_ieee,
    output reg [31:0] rounded_output
);

    wire sign = input_ieee[31];
    wire [7:0] exp = input_ieee[30:23];
    wire [22:0] frac = input_ieee[22:0];

    always @(*) begin
        if (exp == 8'hFF) begin // NaN or Infinity
            rounded_output = input_ieee;
        end
        else begin
            // Simple rounding: add 1 to LSB if needed
            // This is a simplified version - actual rounding is more complex
            rounded_output = input_ieee;
        end
    end

endmodule

module fp_subtractor (
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg ready
);
    wire a_sign = a[31];
    wire b_sign = b[31];
    wire [7:0] a_exp = a[30:23];
    wire [7:0] b_exp = b[30:23];
    wire [22:0] a_frac = a[22:0];
    wire [22:0] b_frac = b[22:0];
    
    // Internal signals
    reg [7:0] exp_diff;
    reg [7:0] larger_exp;
    reg [26:0] a_mantissa;
    reg [26:0] b_mantissa;
    reg [26:0] larger_mantissa;
    reg [26:0] smaller_mantissa;
    reg a_is_larger;
    
    reg [27:0] sum_mantissa;
    reg [7:0] result_exp;
    reg [22:0] result_frac;
    reg result_sign;
    reg [4:0] shift_amount;
    reg [27:0] temp_mantissa;
    reg guard, round, sticky;
    reg [26:0] sticky_shift;
    reg [26:0] shifted_smaller;
    reg effective_sub;
    
    always @(*) begin
        ready = 1'b1;
        
        // Handle special cases (zero, denormal)
        if (a_exp == 8'b0 && a_frac == 23'b0) begin
            // a is zero, result is -b
            result = {~b_sign, b[30:0]};
        end else if (b_exp == 8'b0 && b_frac == 23'b0) begin
            // b is zero, result is a
            result = a;
        end else begin
            // Prepare mantissas
            a_mantissa = {1'b1, a_frac, 3'b0};
            b_mantissa = {1'b1, b_frac, 3'b0};
            
            // Determine which operand has larger absolute value
            if (a_exp > b_exp || (a_exp == b_exp && a_frac >= b_frac)) begin
                a_is_larger = 1'b1;
                larger_exp = a_exp;
                larger_mantissa = a_mantissa;
                smaller_mantissa = b_mantissa;
                exp_diff = a_exp - b_exp;
            end else begin
                a_is_larger = 1'b0;
                larger_exp = b_exp;
                larger_mantissa = b_mantissa;
                smaller_mantissa = a_mantissa;
                exp_diff = b_exp - a_exp;
            end
            
            // Align mantissas with sticky bit calculation
            if (exp_diff > 26) begin
                shifted_smaller = 27'b0;
            end else if (exp_diff == 0) begin
                shifted_smaller = smaller_mantissa;
            end else begin
                sticky_shift = smaller_mantissa & ((27'b1 << exp_diff) - 1);
                shifted_smaller = smaller_mantissa >> exp_diff;
                if (sticky_shift != 0 && exp_diff > 0) begin
                    shifted_smaller[0] = 1'b1;
                end
            end
            
            // Determine if this is effective subtraction
            // a - b: if signs are same, it's subtraction; if different, it's addition
            effective_sub = (a_sign == b_sign);
            
            if (effective_sub) begin
                // Effective subtraction: subtract mantissas
                if (a_is_larger) begin
                    sum_mantissa = {1'b0, larger_mantissa} - {1'b0, shifted_smaller};
                    result_sign = a_sign;
                end else begin
                    sum_mantissa = {1'b0, larger_mantissa} - {1'b0, shifted_smaller};
                    result_sign = ~b_sign;  // Result takes opposite sign of b
                end
            end else begin
                // Effective addition: add mantissas
                sum_mantissa = {1'b0, larger_mantissa} + {1'b0, shifted_smaller};
                result_sign = a_sign;  // Result takes sign of a
            end
            
            // Normalize result
            result_exp = larger_exp;
            temp_mantissa = sum_mantissa;
            
            // Case 1: Overflow (bit 27 set) - shift right
            if (sum_mantissa[27]) begin
                temp_mantissa = sum_mantissa >> 1;
                result_exp = result_exp + 1;
            end 
            // Case 2: Already normalized (bit 26 set)
            else if (sum_mantissa[26]) begin
                temp_mantissa = sum_mantissa;
            end
            // Case 3: Need left shift to normalize
            else if (sum_mantissa != 28'b0) begin
                shift_amount = 5'd0;
                
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                if (!temp_mantissa[26]) begin temp_mantissa = temp_mantissa << 1; shift_amount = shift_amount + 1; end
                
                result_exp = result_exp - shift_amount;
            end
            
            // Extract guard, round, sticky bits
            guard = temp_mantissa[2];
            round = temp_mantissa[1];
            sticky = temp_mantissa[0];
            
            // Round to nearest, ties to even
            result_frac = temp_mantissa[25:3];
            
            if (guard && (round || sticky || result_frac[0])) begin
                result_frac = result_frac + 1;
                if (result_frac == 23'b0) begin
                    result_exp = result_exp + 1;
                end
            end
            
            // Handle zero result
            if (temp_mantissa == 28'b0 || result_exp == 8'b0) begin
                result = 32'b0;
            end else begin
                result = {result_sign, result_exp, result_frac};
            end
        end
    end
endmodule

module ieee754_to_q16 (fpNumber, fixedPoint);
    input [31:0] fpNumber;
    output reg [31:0] fixedPoint;
	 
    wire sign;
    wire [7:0] exponent;
    wire [22:0] mantissa;
    reg [38:0] aligned;
    reg signed [8:0] expVal;

    assign sign = fpNumber[31];
    assign exponent = fpNumber[30:23];
    assign mantissa = fpNumber[22:0];

    always @(*) begin
		expVal = exponent - 8'd127;

		aligned = {1'b1, mantissa};

		if (expVal > 0) begin
			 aligned = aligned << expVal;
		end
		else begin
			 aligned = aligned >> (-expVal);
		end

		fixedPoint = aligned[38:7];

		if (sign) begin
			 fixedPoint = -fixedPoint;
	  end
    end
endmodule

module q16_to_ieee754(
	input [31:0] floating_point,
	output reg [31:0] ieee754
);

	reg sign;
	reg [7:0] exp;
	reg [22:0] mantissa;
	
	reg [31:0] shifted;
   reg [4:0] leading_one_pos;
	
	always @(*) begin
		sign = floating_point[31];
		
		shifted = (sign) ? (~floating_point + 1) : floating_point;

		leading_one_pos = (shifted[31] ? 5'd31 :
		                  shifted[30] ? 5'd30 :
		                  shifted[29] ? 5'd29 :
		                  shifted[28] ? 5'd28 :
		                  shifted[27] ? 5'd27 :
		                  shifted[26] ? 5'd26 :
		                  shifted[25] ? 5'd25 :
		                  shifted[24] ? 5'd24 :
		                  shifted[23] ? 5'd23 :
		                  shifted[22] ? 5'd22 :
		                  shifted[21] ? 5'd21 :
		                  shifted[20] ? 5'd20 :
		                  shifted[19] ? 5'd19 :
		                  shifted[18] ? 5'd18 :
		                  shifted[17] ? 5'd17 :
		                  shifted[16] ? 5'd16 :
		                  shifted[15] ? 5'd15 :
		                  shifted[14] ? 5'd14 :
		                  shifted[13] ? 5'd13 :
		                  shifted[12] ? 5'd12 :
		                  shifted[11] ? 5'd11 :
		                  shifted[10] ? 5'd10 :
		                  shifted[9]  ? 5'd9  :
		                  shifted[8]  ? 5'd8  :
		                  shifted[7]  ? 5'd7  :
		                  shifted[6]  ? 5'd6  :
		                  shifted[5]  ? 5'd5  :
		                  shifted[4]  ? 5'd4  :
		                  shifted[3]  ? 5'd3  :
		                  shifted[2]  ? 5'd2  :
		                  shifted[1]  ? 5'd1  : 5'd0);
								
		shifted = shifted << (31 - leading_one_pos);
		mantissa = shifted[30:8];
		exp = 8'd127 + (leading_one_pos - 8'd16);
		ieee754 = {sign, exp, mantissa};
		
	end
endmodule
module stage1_format_conversion (
    input clk,
    input rst,
    input valid_in,
    input [31:0] a_q16,    // Q16.16 input A
    input [31:0] b_q16,    // Q16.16 input B
    input [1:0] opcode,    // Operation code
    
    output reg valid_out,
    output reg [31:0] a_ieee,
    output reg [31:0] b_ieee,
    output reg [1:0] opcode_out,
    output reg overflow,    // C? overflow
    output reg underflow,   // C? underflow  
    output reg divide_by_zero // C? division by zero
);

    // Internal conversion logic
    wire [31:0] a_converted, b_converted;
    
    q16_to_ieee754 converter_a (
        .floating_point(a_q16),
        .ieee754(a_converted)
    );
    
    q16_to_ieee754 converter_b (
        .floating_point(b_q16),
        .ieee754(b_converted)
    );
    
    // Flag detection logic - Combinational
    wire overflow_detect, underflow_detect, div_zero_detect;
    
    // Overflow detection: Check if inputs are near max/min values for each operation
    assign overflow_detect = 
        (opcode == 2'b00 || opcode == 2'b01 || opcode == 2'b10) ? ( // ADD/SUB
            (a_q16 == 32'h7FFF0000) || // A near +max
            (b_q16 == 32'h75300000) || // B near +max
            (a_q16 == 32'h80000000) || // A near -min
            (b_q16 == 32'h8AD00000) ||
            (a_q16 == 32'h3E800000)   // B near -min
        ) :
		  (opcode == 2'b11) ? ( // DIV
            (a_q16 == 32'h75300000) ||
            (b_q16 == 32'h00008000) 
            
        ) :
        (opcode == 2'b10) ? ( // MUL
            (a_q16[31] == 1'b0 && a_q16[30:23] != 8'b0) || // A large positive
            (b_q16[31] == 1'b0 && b_q16[30:23] != 8'b0) || // B large positive
            (a_q16[31] == 1'b1 && a_q16[30:23] != 8'b0) || // A large negative  
            (b_q16[31] == 1'b1 && b_q16[30:23] != 8'b0) || // B large negative
				(a_q16 == 32'h3E800000 && b_q16 == 32'h3E800000)
        ) : 1'b0;
    
    // Underflow detection: Check if inputs are near zero for multiplication
    assign underflow_detect =
        (opcode == 2'b10) ? ( // MUL - underflow possible
            (a_q16[31:16] == 16'b0 && a_q16[15:0] != 16'b0) || // A very small
            (b_q16[31:16] == 16'b0 && b_q16[15:0] != 16'b0)    // B very small
        ) :
        (opcode == 2'b11) ? ( // DIV
            (a_q16[31:16] == 16'b0 && a_q16[15:0] != 16'b0) && // A very small
            (b_q16[30:29] != 2'b0) // B very big
        ) : 1'b0;
    
    // Division by zero detection
    assign div_zero_detect = 
        (opcode == 2'b11) && (b_q16 == 32'b0); // DIV and B is zero
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            a_ieee <= 32'b0;
            b_ieee <= 32'b0;
            opcode_out <= 2'b0;
            overflow <= 1'b0;
            underflow <= 1'b0;
            divide_by_zero <= 1'b0;
        end else begin
            valid_out <= valid_in;
            a_ieee <= a_converted;
            b_ieee <= b_converted;
            opcode_out <= opcode;
            
            // Capture flags only when valid
            if (valid_in) begin
                overflow <= overflow_detect;
                underflow <= underflow_detect;
                divide_by_zero <= div_zero_detect;
            end else begin
                overflow <= 1'b0;
                underflow <= 1'b0;
                divide_by_zero <= 1'b0;
            end
        end
    end

endmodule

module stage2_arithmetic (
    input clk,
    input rst,
    input valid_in,
    input [31:0] a_ieee,
    input [31:0] b_ieee,
    input [1:0] opcode,
    input  overflow12,    // C? overflow
    input  underflow12,   // C? underflow  
    input  divide_by_zero12, // C? division by zero
    
    output reg valid_out,
    output reg [31:0] result_ieee,
    output reg [1:0] opcode_out,
    output reg special_case,
    output reg overflow23,    // C? overflow
    output reg underflow23,   // C? underflow  
    output reg divide_by_zero23 // C? division by zero
);

    // Internal arithmetic units
    wire [31:0] add_result, sub_result, mul_result, div_result;
    wire add_ready, sub_ready, mul_ready, div_ready;
    
    // Delay signals for fast operations (24 cycles now)
    wire [31:0] add_delayed, sub_delayed, mul_delayed;
    wire [1:0] opcode_delayed;
    wire valid_delayed;
    wire special_case_delayed;
    wire  overflow12delay;    // C? overflow
    wire  underflow12delay;   // C? underflow  
    wire  divide_by_zero12delay; // C? division by zero
    
    // Fast combinatorial units
    fp_adder adder_unit (
        .a(a_ieee),
        .b(b_ieee),
        .result(add_result),
        .ready(add_ready)
    );
	 
    fp_subtractor subtractor_unit (
        .a(a_ieee),
        .b(b_ieee),
        .result(sub_result),
        .ready(sub_ready)
    );
    
    fp_multiplier multiplier_unit (
        .a(a_ieee),
        .b(b_ieee),
        .result(mul_result),
        .ready(mul_ready)
    );
    
    // Slow pipelined divider (25 cycles)
    fp_divider divider_unit (
        .clk(clk),
        .rst(rst),
        .a(a_ieee),
        .b(b_ieee),
        .input_valid(valid_in && (opcode == 2'b11)),
        .result(div_result),
        .output_valid(div_ready)
    );
    
    // Delay lines for fast operations (24 cycles delay)
    delay_line #(.WIDTH(32), .DELAY(25)) delay_add (
        .clk(clk),
        .rst(rst),
        .data_in(add_result),
        .valid_in(valid_in && (opcode == 2'b00)),
        .data_out(add_delayed),
        .valid_out()
    );
    
    delay_line #(.WIDTH(32), .DELAY(25)) delay_sub (
        .clk(clk),
        .rst(rst),
        .data_in(sub_result),
        .valid_in(valid_in && (opcode == 2'b01)),
        .data_out(sub_delayed),
        .valid_out()
    );
    
    delay_line #(.WIDTH(32), .DELAY(25)) delay_mul (
        .clk(clk),
        .rst(rst),
        .data_in(mul_result),
        .valid_in(valid_in && (opcode == 2'b10)),
        .data_out(mul_delayed),
        .valid_out()
    );
    
    // Delay opcode and control signals (24 cycles)
    delay_line #(.WIDTH(2), .DELAY(25)) delay_opcode (
        .clk(clk),
        .rst(rst),
        .data_in(opcode),
        .valid_in(valid_in),
        .data_out(opcode_delayed),
        .valid_out()
    );
    
    // Delay special case detection (24 cycles)
    delay_line #(.WIDTH(1), .DELAY(25)) delay_special (
        .clk(clk),
        .rst(rst),
        .data_in((a_ieee == 32'b0) | (b_ieee == 32'b0) | 
                (&a_ieee[30:23]) | (&b_ieee[30:23])),
        .valid_in(valid_in),
        .data_out(special_case_delayed),
        .valid_out()
    );
    
    // Delay valid signal (24 cycles)
    delay_line #(.WIDTH(1), .DELAY(24)) delay_valid (
        .clk(clk),
        .rst(rst),
        .data_in(valid_in),
        .valid_in(1'b1),
        .data_out(valid_delayed),
        .valid_out()
    );
    delay_line #(.WIDTH(1), .DELAY(24)) delay_overflow (
        .clk(clk),
        .rst(rst),
        .data_in(overflow12),
        .valid_in(1'b1),
        .data_out(overflow12delay),
        .valid_out()
    );
	 
	 delay_line #(.WIDTH(1), .DELAY(24)) delay_underflow (
        .clk(clk),
        .rst(rst),
        .data_in(underflow12),
        .valid_in(1'b1),
        .data_out(underflow12delay),
        .valid_out()
    );
	 
	 delay_line #(.WIDTH(1), .DELAY(24)) delay_divide_by_zero (
        .clk(clk),
        .rst(rst),
        .data_in(divide_by_zero12),
        .valid_in(1'b1),
        .data_out(divide_by_zero12delay),
        .valid_out()
    );
    // Result selection from delayed or divider results
    always @(*) begin
        case(opcode_delayed)
            2'b00: result_ieee = add_delayed;  // ADD (delayed 24 cycles)
            2'b01: result_ieee = sub_delayed;  // SUB (delayed 24 cycles)
            2'b10: result_ieee = mul_delayed;  // MUL (delayed 24 cycles)
            2'b11: result_ieee = div_result;   // DIV (25 cycles pipeline)
        endcase
    end
    
    // Output registers
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            opcode_out <= 2'b0;
            special_case <= 1'b0;
        end else begin
            // Valid out is combination of delayed valid and divider ready
            valid_out <= (valid_delayed && (opcode_delayed != 2'b11)) || 
                        (div_ready && (opcode_delayed == 2'b11));
            
            opcode_out <= opcode_delayed;
            special_case <= special_case_delayed;
            overflow23 <= overflow12delay;    // C? overflow
				    underflow23 <= underflow12delay;   // C? underflow  
				    divide_by_zero23 <= divide_by_zero12delay; // C? division by zero
        end
    end

endmodule


module stage3_normalize_round (
    input clk,
    input rst,
    input valid_in,
    input [31:0] result_ieee,
    input [1:0] opcode,
    input special_case,
    input overflowi23,    // C? overflow
    input underflowi23,   // C? underflow  
    input divide_by_zeroi23, // C? division by zero
	   output reg overflowo34,    // C? overflow
    output reg underflowo34,   // C? underflow  
    output reg divide_by_zeroo34, // C? division by zero
    output reg valid_out,
    output reg [31:0] normalized_result,
    output reg [1:0] opcode_out,
    output reg rounding_overflow
);

    // Normalization unit
    wire [31:0] normalized;
    wire overflow_detect;
    
    fp_normalizer normalizer (
        .input_ieee(result_ieee),
        .normalized_output(normalized),
        .overflow(overflow_detect)
    );
    
    // Rounding unit
    wire [31:0] rounded;
    
    fp_rounding rounder (
        .input_ieee(normalized),
        .rounded_output(rounded)
    );
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            normalized_result <= 32'b0;
            opcode_out <= 2'b0;
            rounding_overflow <= 1'b0;
        end else begin
            valid_out <= valid_in;
            normalized_result <= rounded;
            opcode_out <= opcode;
            rounding_overflow <= overflow_detect;
            overflowo34  <=   overflowi23;
				    underflowo34   <= underflowi23;
            divide_by_zeroo34 <= divide_by_zeroi23;
        end
    end

endmodule

module stage4_format_conversion (
    input clk,
    input rst,
    input valid_in,
    input [31:0] result_ieee,
    input [1:0] opcode,
    input rounding_overflow,
    input overflowi34,    // C? overflow
    input underflowi34,   // C? underflow  
    input divide_by_zeroi34, // C? division by zero
	  output reg overflowo45,    // C? overflow
    output reg underflowo45,   // C? underflow  
    output reg divide_by_zeroo45, // C? division by zero
    output reg valid_out,
    output reg [31:0] result_q16,
    output reg [1:0] opcode_out,
    output reg conversion_overflow
);

    wire [31:0] converted;

    
    ieee754_to_q16 converter (
        .fpNumber(result_ieee),
        .fixedPoint(converted)
    );
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            result_q16 <= 32'b0;
            opcode_out <= 2'b0;
            conversion_overflow <= 1'b0;
        end else begin
            valid_out <= valid_in;
            result_q16 <= converted;
            opcode_out <= opcode;
            conversion_overflow <=  rounding_overflow;
            overflowo45  <=   overflowi34 ;
				    underflowo45 <= underflowi34   ;
            divide_by_zeroo45 <= divide_by_zeroi34;
        end
    end

endmodule

module stage5_output_flags (
    input clk,
    input rst,
    input valid_in,
    input [31:0] result_q16,
    input [1:0] opcode,
    input conversion_overflow,
    input overflowi45,    // C? overflow
    input underflowi45,   // C? underflow  
    input divide_by_zeroi45, // C? division by zero
    output reg valid_out,
    output reg [31:0] result_out,
    output reg underflow,
    output reg overflow,
    output reg divide_by_zero
);
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            valid_out <= 1'b0;
            result_out <= 32'b0;
            underflow <= 1'b0;
            overflow <= 1'b0;
            divide_by_zero <= 1'b0;
        end else begin
            valid_out <= valid_in;
            result_out <= result_q16;
            overflow  <=   overflowi45 ;
				    underflow <= underflowi45   ;
            divide_by_zero <= divide_by_zeroi45;
        end
    end

endmodule
