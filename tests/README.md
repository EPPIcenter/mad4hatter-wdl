# WDL Pipeline Tests

This directory contains tests for the MAD4HatTeR WDL pipeline, replicated from the Nextflow pipeline tests.

## Overview

The test suite validates WDL tasks and workflows by:
1. Running WDL tasks/workflows with test input data
2. Validating output files exist
3. Comparing MD5 checksums of output files against expected values

This approach mirrors the `nf-test` framework used in the Nextflow version of the pipeline.

## Test Structure

```
tests/
├── README.md                          # This file
├── run_tests.sh                       # Main test runner script
├── example_data/                      # Test input data files
│   ├── *.tsv                          # Amplicon info and other TSV files
│   ├── *.txt                          # Alignment and cluster files
│   ├── *.fasta                        # Reference sequences
│   └── cutadapt_examples/             # FASTQ files for QC tests
├── modules/
│   └── local/
│       ├── *.test.json                # Test input JSON files
│       └── *.test.expected.txt        # Expected output MD5 checksums
└── workflows/
    ├── *.test.json                    # Test input JSON files
    └── *.test.expected.txt            # Expected output MD5 checksums
```

## Prerequisites

### Required Software

1. **miniwdl** - WDL execution engine
   ```bash
   pip install miniwdl
   ```

2. **Python 3** - For test script utilities

3. **jq** (optional) - For JSON processing
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo apt-get install jq
   ```

### Docker

The tests require the MAD4HatTeR Docker image to be available:
- `eppicenter/mad4hatter:develop`

Make sure Docker is running and the image is pulled:
```bash
docker pull eppicenter/mad4hatter:develop
```

## Running Tests

### Run All Tests

From the project root directory:
```bash
./tests/run_tests.sh
```

Or from the tests directory:
```bash
cd tests
./run_tests.sh
```

### Run Specific Tests

You can modify the test script or run miniwdl directly:

```bash
# Run a specific module test
miniwdl run modules/local/build_alleletable.wdl \
  -i tests/modules/local/build_alleletable.test.json \
  --dir test_outputs

# Run a specific workflow test
miniwdl run workflows/postproc_only.wdl \
  -i tests/workflows/postproc_only.test.json \
  --dir test_outputs
```

### Test Output

Test results are stored in `tests/test_results/`:
- Each test has its own subdirectory
- `run.log` contains the execution log
- `outputs.json` contains the workflow outputs
- `workdir/` contains the full execution directory

## Test Files

### Test Input JSON Files (`.test.json`)

These files contain the input parameters for each test, similar to Nextflow's test `when` blocks:

```json
{
  "build_alleletable.amplicon_info_ch": "tests/example_data/multi_pool_amplicon_info.tsv",
  "build_alleletable.denoised_asvs": "tests/example_data/dada2.clusters.txt",
  "build_alleletable.docker_image": "eppicenter/mad4hatter:develop"
}
```

### Expected Output Files (`.test.expected.txt`)

These files define the expected MD5 checksums for output files:

```
# Expected outputs with MD5 checksums
# Format: output_name=expected_md5
build_alleletable.alleledata=f95f286b1dd881d7ff242e43a0c1e20f
build_alleletable.alleledata_collapsed=35dc5cab42851504b95c6e25ff491598
```

## Available Tests

### Module Tests

- **build_alleletable** - Tests allele table generation
- **build_pseudocigar** - Tests pseudocigar generation (SNPs, indels, masked)
- **collapse_concatenated_reads** - Tests concatenated read collapsing
- **preprocess_coverage** - Tests coverage preprocessing
- **build_resmarker_info_and_resistance_table** - Tests resistance marker analysis

### Workflow Tests

- **postproc_only** - Tests post-processing workflow (with and without masking)
- **qc_only** - Tests quality control workflow

## Adding New Tests

### 1. Create Test Input JSON

Create a file `tests/modules/local/your_task.test.json`:

```json
{
  "your_task.input_param": "tests/example_data/input_file.txt",
  "your_task.docker_image": "eppicenter/mad4hatter:develop"
}
```

### 2. Create Expected Outputs File

Create a file `tests/modules/local/your_task.test.expected.txt`:

```
# Expected outputs with MD5 checksums
your_task.output_file=expected_md5_checksum_here
```

To get the MD5 checksum of an expected output:
```bash
# macOS
md5 -q expected_output_file.txt

# Linux
md5sum expected_output_file.txt | cut -d' ' -f1
```

### 3. Run the Test

```bash
./tests/run_tests.sh
```

The test runner will automatically discover and run your new test.

## Troubleshooting

### Test Failures

1. **MD5 Checksum Mismatch**
   - The output file was generated but differs from expected
   - Check if the WDL implementation changed
   - Verify the expected MD5 is correct for the current implementation
   - Update the `.test.expected.txt` file if the change is intentional

2. **File Not Found**
   - Check that input files exist in `tests/example_data/`
   - Verify file paths in the test JSON are correct
   - Ensure paths are relative to the project root

3. **Execution Failed**
   - Check `tests/test_results/<test_name>/run.log` for error messages
   - Verify Docker image is available: `docker images | grep mad4hatter`
   - Ensure all required input files are present

4. **miniwdl Not Found**
   - Install miniwdl: `pip install miniwdl`
   - Verify it's in PATH: `which miniwdl`

### Updating Expected Outputs

If the WDL implementation changes and outputs legitimately differ:

1. Run the test to generate new outputs
2. Calculate new MD5 checksums:
   ```bash
   md5 -q tests/test_results/<test_name>/workdir/outputs/<output_file>
   ```
3. Update the `.test.expected.txt` file with new checksums

## Test Coverage

The test suite covers:

- ✅ Core module tasks (build_alleletable, build_pseudocigar, etc.)
- ✅ Workflow-level tests (postproc_only, qc_only)
- ✅ Multiple parameter configurations
- ✅ Output validation via MD5 checksums

## Comparison with Nextflow Tests

This WDL test suite replicates the functionality of the Nextflow `nf-test` framework:

| Nextflow (nf-test) | WDL (this suite) |
|-------------------|------------------|
| `nextflow_process` block | Module `.test.json` files |
| `nextflow_workflow` block | Workflow `.test.json` files |
| `when { params { ... } }` | Test input JSON files |
| `then { assert ... md5 == ... }` | `.test.expected.txt` files |
| `nf-test run` | `./tests/run_tests.sh` |

## Continuous Integration

To integrate tests into CI/CD:

```yaml
# Example GitHub Actions workflow
- name: Run WDL Tests
  run: |
    pip install miniwdl
    ./tests/run_tests.sh
```

## License

Tests follow the same license as the main pipeline.

