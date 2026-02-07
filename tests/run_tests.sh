#!/usr/bin/env bash

# WDL Test Runner Script
# This script runs WDL tests and validates outputs using MD5 checksums
# Similar to nf-test for Nextflow pipelines

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}"
RESULTS_DIR="${TEST_DIR}/test_results"
MINIWDL_CMD="${MINIWDL_CMD:-miniwdl run}"
VERBOSE="${VERBOSE:-false}"

# Test results tracking
PASSED=0
FAILED=0
SKIPPED=0

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to calculate MD5 checksum
calculate_md5() {
    local file="$1"
    if [[ -f "$file" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            md5 -q "$file"
        else
            md5sum "$file" | cut -d' ' -f1
        fi
    else
        echo ""
    fi
}

# Function to check if miniwdl is available
check_miniwdl() {
    if ! command -v miniwdl &> /dev/null; then
        print_error "miniwdl is not installed or not in PATH"
        print_info "Install miniwdl with: pip install miniwdl"
        exit 1
    fi
}

# Function to run a single test
run_test() {
    local wdl_file="$1"
    local json_file="$2"
    local test_name="$3"
    local expected_outputs="$4"
    
    print_info "Running test: ${test_name}"
    print_info "  WDL: ${wdl_file}"
    print_info "  Input: ${json_file}"
    
    # Create results directory for this test
    local test_result_dir="${RESULTS_DIR}/${test_name}"
    mkdir -p "${test_result_dir}"
    
    # Convert relative paths in JSON to absolute paths
    local json_abs="${test_result_dir}/input.json"
    python3 <<PYTHON
import json
import os

with open("${json_file}", "r") as f:
    data = json.load(f)

# Convert file paths to absolute paths
def convert_paths(obj, base_dir):
    if isinstance(obj, dict):
        return {k: convert_paths(v, base_dir) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_paths(item, base_dir) for item in obj]
    elif isinstance(obj, str) and (obj.startswith("tests/") or obj.startswith("./tests/")):
        abs_path = os.path.join("${PROJECT_ROOT}", obj.lstrip("./"))
        return abs_path
    return obj

data = convert_paths(data, "${PROJECT_ROOT}")

with open("${json_abs}", "w") as f:
    json.dump(data, f, indent=2)
PYTHON
    
    # Run the WDL task/workflow
    local exit_code=0
    local output_file="${test_result_dir}/output.json"
    
    cd "${PROJECT_ROOT}"
    # For tasks inside build_resources.wdl, we need to specify the task name
    local miniwdl_cmd="${MINIWDL_CMD}"
    if [[ "$wdl_file" == *"build_resources.wdl" ]]; then
        # Extract task name from test basename
        local task_name="${test_basename}"
        # Remove variant suffixes to get base task name
        task_name="${task_name%_single}"
        # If it's still not a valid task name, try build_targeted_reference
        if [[ "$task_name" != "build_targeted_reference" && "$task_name" != "build_amplicon_info" ]]; then
            task_name="build_targeted_reference"
        fi
        miniwdl_cmd="${MINIWDL_CMD} --task ${task_name}"
    fi
    
    if ${miniwdl_cmd} "${wdl_file}" -i "${json_abs}" --dir "${test_result_dir}/workdir" > "${test_result_dir}/run.log" 2>&1; then
        # Extract outputs from miniwdl output
        # miniwdl creates a timestamped subdirectory, so we need to find the outputs.json file
        local outputs_json=""
        # First try the direct path (for tasks)
        if [[ -f "${test_result_dir}/workdir/outputs.json" ]]; then
            outputs_json="${test_result_dir}/workdir/outputs.json"
        else
            # For workflows, outputs.json is in a timestamped subdirectory
            # Find the workflow-level outputs.json (not in call-* subdirectories)
            # The workflow outputs.json is in the timestamped directory, not in call subdirectories
            # Strategy: find outputs.json files, exclude those in call-* directories, prefer the one in timestamped dir
            outputs_json=$(find "${test_result_dir}/workdir" -name "outputs.json" -type f 2>/dev/null | grep -v "/call-" | head -1)
            # If that didn't work, try the prune method
            if [[ -z "$outputs_json" ]]; then
                outputs_json=$(find "${test_result_dir}/workdir" -path "*/call-*" -prune -o -name "outputs.json" -type f -print 2>/dev/null | head -1)
            fi
            # Last resort: take the first one found (but this might be a task output)
            if [[ -z "$outputs_json" ]]; then
                outputs_json=$(find "${test_result_dir}/workdir" -name "outputs.json" -type f 2>/dev/null | head -1)
            fi
        fi
        
        if [[ -n "$outputs_json" && -f "$outputs_json" ]]; then
            cp "$outputs_json" "${output_file}"
        fi
        
        # Validate expected outputs
        local all_passed=true
        # For e2e tests, if expected file is empty or only has comments, skip validation
        local has_expected_outputs=false
        if [[ -n "$expected_outputs" ]]; then
            # Check if file has any non-comment, non-empty lines with = sign
            if echo "$expected_outputs" | grep -qE '^[^#]*=.*$'; then
                has_expected_outputs=true
            fi
        fi
        
        # If no expected outputs (e.g., e2e tests), just check for success
        if [[ "$has_expected_outputs" == "false" ]]; then
            print_success "Test passed: ${test_name} (e2e test - success only)"
            ((PASSED++))
            return 0
        fi
        
        while IFS='=' read -r output_name expected_md5; do
            if [[ -z "$output_name" || "$output_name" =~ ^# ]]; then
                continue
            fi
            
            # Extract the actual file path from outputs.json
            local actual_file=""
            if [[ -f "${output_file}" ]]; then
                actual_file=$(python3 <<PYTHON
import json
import sys
import os

try:
    with open("${output_file}", "r") as f:
        data = json.load(f)
    
    # miniwdl outputs.json can have different structures:
    # 1. Direct outputs: {"workflow_name.output_name": [...]}
    # 2. Nested with "outputs" key: {"outputs": {"workflow_name.output_name": [...]}}
    # 3. Task outputs: {"output_name": "path"}
    
    # Extract the actual outputs dictionary
    if "outputs" in data and isinstance(data["outputs"], dict):
        outputs = data["outputs"]
    else:
        outputs = data
    
    # Handle output paths - miniwdl uses different formats:
    # 1. For workflows: "workflow_name.output_name" as a direct key
    # 2. For tasks: "output_name" as a direct key
    # 3. For nested structures: nested dictionaries
    
    output_key = "${output_name}"
    value = None
    
    # Strategy 1: Try exact key match first (for workflows with "workflow_name.output_name" keys)
    if output_key in outputs:
        value = outputs[output_key]
    else:
        # Strategy 2: Try nested navigation (for nested dictionary structures)
        parts = output_key.split(".")
        if len(parts) > 1:
            temp_value = outputs
            found = True
            for part in parts:
                if isinstance(temp_value, dict) and part in temp_value:
                    temp_value = temp_value[part]
                else:
                    found = False
                    break
            if found:
                value = temp_value
        
        # Strategy 3: Try just the output name (for tasks where key is just "output_name")
        if value is None and len(parts) > 1:
            output_name_only = parts[-1]
            if output_name_only in outputs:
                value = outputs[output_name_only]
    
    # Handle arrays - miniwdl often returns arrays even for single outputs
    if isinstance(value, list):
        if len(value) > 0:
            # If first element is a string (file path), use it
            if isinstance(value[0], str):
                value = value[0]
            # Otherwise, if it's a single element array, use that element
            elif len(value) == 1:
                value = value[0]
            else:
                # Multiple elements - this might be an array output, use first
                value = value[0] if len(value) > 0 else None
        else:
            value = None
    
    # Convert to string and clean up
    if value:
        value_str = str(value)
        # Remove file:// prefix if present
        value_str = value_str.replace("file://", "")
        # Convert to absolute path if relative
        if not os.path.isabs(value_str) and os.path.exists(value_str):
            value_str = os.path.abspath(value_str)
        print(value_str)
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
PYTHON
)
            fi
            
            if [[ -z "$actual_file" ]]; then
                print_error "  Output '${output_name}' not found in results"
                if [[ -f "${output_file}" ]]; then
                    print_info "  Available outputs:"
                    python3 <<PYTHON
import json
try:
    with open("${output_file}", "r") as f:
        data = json.load(f)
    # Check if outputs are nested
    if "outputs" in data and isinstance(data["outputs"], dict):
        outputs = data["outputs"]
    else:
        outputs = data
    print(json.dumps(outputs, indent=2))
except Exception as e:
    print(f"Error reading outputs: {e}")
PYTHON
                    print_info "  Looking for output key: ${output_name}"
                fi
                all_passed=false
                continue
            fi
            
            # Remove file:// prefix if present (redundant but safe)
            actual_file="${actual_file#file://}"
            
            if [[ ! -f "$actual_file" ]]; then
                print_error "  Output file '${actual_file}' does not exist"
                all_passed=false
                continue
            fi
            
            local actual_md5=$(calculate_md5 "$actual_file")
            if [[ "$actual_md5" == "$expected_md5" ]]; then
                print_success "  Output '${output_name}' MD5 matches: ${actual_md5}"
            else
                print_error "  Output '${output_name}' MD5 mismatch"
                print_error "    Expected: ${expected_md5}"
                print_error "    Actual:   ${actual_md5}"
                all_passed=false
            fi
        done <<< "$expected_outputs"
        
        if [[ "$all_passed" == "true" ]]; then
            print_success "Test passed: ${test_name}"
            ((PASSED++))
            return 0
        else
            print_error "Test failed: ${test_name} (output validation failed)"
            ((FAILED++))
            return 1
        fi
    else
        print_error "Test failed: ${test_name} (execution failed)"
        print_error "Check log: ${test_result_dir}/run.log"
        ((FAILED++))
        return 1
    fi
}

# Function to find and run all tests
run_all_tests() {
    print_info "Starting WDL test suite..."
    print_info "Project root: ${PROJECT_ROOT}"
    print_info "Test directory: ${TEST_DIR}"
    
    # Clean previous results
    rm -rf "${RESULTS_DIR}"
    mkdir -p "${RESULTS_DIR}"
    
    # Find all test JSON files
    local test_files=($(find "${TEST_DIR}" -name "*.test.json" -type f | sort))
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_warning "No test files found in ${TEST_DIR}"
        return 1
    fi
    
    print_info "Found ${#test_files[@]} test file(s)"
    
    for json_file in "${test_files[@]}"; do
        # Determine corresponding WDL file
        local test_dir=$(dirname "$json_file")
        local test_basename=$(basename "$json_file" .test.json)
        local wdl_file=""
        
        # Extract base name (remove variant suffixes like _indels, _masked_indels, _no_concat, _empty, _no_masking, etc.)
        # Try to find the base WDL file by removing common variant suffixes
        # Order matters: remove longer suffixes first
        local base_name="${test_basename}"
        base_name="${base_name%_with_postprocess}"
        base_name="${base_name%_no_postprocess}"
        base_name="${base_name%_no_refseq}"
        base_name="${base_name%_with_refseq}"
        base_name="${base_name%_no_concatenate}"
        base_name="${base_name%_build_info}"
        base_name="${base_name%_provided_info}"
        base_name="${base_name%_with_genome}"
        base_name="${base_name%_with_targeted}"
        base_name="${base_name%_both}"
        base_name="${base_name%_homo_only}"
        base_name="${base_name%_tr_only}"
        base_name="${base_name%_masked_indels}"
        base_name="${base_name%_no_masking}"
        base_name="${base_name%_no_concat}"
        base_name="${base_name%_indels}"
        base_name="${base_name%_empty}"
        base_name="${base_name%_single}"
        base_name="${base_name%_basic}"
        
        # Try to find WDL file in modules, workflows, subworkflows, or e2e
        if [[ "$test_dir" == *"modules/local"* ]]; then
            wdl_file="${PROJECT_ROOT}/modules/local/${base_name}.wdl"
            # If base name doesn't exist, try the original test basename
            if [[ ! -f "$wdl_file" ]]; then
                wdl_file="${PROJECT_ROOT}/modules/local/${test_basename}.wdl"
            fi
            # Special handling for tasks inside build_resources.wdl
            # Remove _single suffix before checking
            local check_name="${base_name%_single}"
            if [[ ! -f "$wdl_file" && ("$check_name" == "build_targeted_reference" || "$check_name" == "build_amplicon_info") ]]; then
                wdl_file="${PROJECT_ROOT}/modules/local/build_resources.wdl"
            fi
            # Additional variant handling for mask_sequences
            if [[ ! -f "$wdl_file" && "$base_name" =~ ^mask_sequences ]]; then
                wdl_file="${PROJECT_ROOT}/modules/local/mask_sequences.wdl"
            fi
        elif [[ "$test_dir" == *"workflows"* ]]; then
            wdl_file="${PROJECT_ROOT}/workflows/${base_name}.wdl"
            # If base name doesn't exist, try the original test basename
            if [[ ! -f "$wdl_file" ]]; then
                wdl_file="${PROJECT_ROOT}/workflows/${test_basename}.wdl"
            fi
        elif [[ "$test_dir" == *"subworkflows/local"* ]]; then
            # For subworkflows, the base_name should already have suffixes removed
            # But let's make sure by checking the file directly
            wdl_file="${PROJECT_ROOT}/subworkflows/local/${base_name}.wdl"
            # If not found, try the original test basename (in case suffix removal didn't work)
            if [[ ! -f "$wdl_file" ]]; then
                wdl_file="${PROJECT_ROOT}/subworkflows/local/${test_basename}.wdl"
            fi
        elif [[ "$test_dir" == *"e2e"* ]]; then
            # E2E tests use main workflow files in project root
            wdl_file="${PROJECT_ROOT}/${base_name}.wdl"
            # If base name doesn't exist, try the original test basename
            if [[ ! -f "$wdl_file" ]]; then
                wdl_file="${PROJECT_ROOT}/${test_basename}.wdl"
            fi
        fi
        
        if [[ ! -f "$wdl_file" ]]; then
            # For subworkflows, provide more helpful error message
            if [[ "$test_dir" == *"subworkflows/local"* ]]; then
                print_warning "Skipping ${json_file}: WDL file not found (tried ${base_name}.wdl, ${test_basename}.wdl, and variants)"
            else
                print_warning "Skipping ${json_file}: WDL file not found (tried ${base_name}.wdl and ${test_basename}.wdl)"
            fi
            ((SKIPPED++))
            continue
        fi
        
        # Read expected outputs from test file (if present)
        local expected_outputs=""
        local expected_file="${json_file%.json}.expected.txt"
        if [[ -f "$expected_file" ]]; then
            expected_outputs=$(cat "$expected_file")
        fi
        
        # Run the test
        local test_name="${test_dir##*/}/${test_basename}"
        run_test "$wdl_file" "$json_file" "$test_name" "$expected_outputs" || true
    done
    
    # Print summary
    echo ""
    print_info "Test Summary:"
    print_success "  Passed: ${PASSED}"
    if [[ $FAILED -gt 0 ]]; then
        print_error "  Failed: ${FAILED}"
    fi
    if [[ $SKIPPED -gt 0 ]]; then
        print_warning "  Skipped: ${SKIPPED}"
    fi
    
    if [[ $FAILED -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    check_miniwdl
    run_all_tests
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

