# Test Coverage Summary

## Overview

This document summarizes all tests created for the WDL pipeline, organized by category.

## Test Statistics

- **Module Tests**: 20+ tests
- **Workflow Tests**: 10+ tests  
- **Subworkflow Tests**: 5+ tests
- **E2E Tests**: 3 tests
- **Total**: 38+ tests

## Module Tests

Located in `tests/modules/local/`:

### Core Processing Modules
- ✅ `build_alleletable` - Allele table generation
- ✅ `build_pseudocigar` - Pseudocigar generation (3 variants: SNPs, indels, masked indels)
- ✅ `build_resmarker_info_and_resistance_table` - Resistance marker analysis (2 variants)
- ✅ `collapse_concatenated_reads` - Read collapsing (2 variants)
- ✅ `preprocess_coverage` - Coverage preprocessing
- ✅ `postprocess_coverage` - Coverage postprocessing

### Reference and Primer Modules
- ✅ `create_primer_files` - Primer file generation
- ✅ `create_reference_from_genomes` - Reference extraction from genomes
- ✅ `build_targeted_reference` - Reference merging (2 variants)

### Masking Modules
- ✅ `mask_reference_homopolymers` - Homopolymer masking
- ✅ `mask_sequences` - Sequence masking (4 variants: homo, tr, both, hapseq)

### Alignment Modules
- ✅ `align_to_reference_and_filter_asvs` - Alignment and ASV filtering

## Workflow Tests

Located in `tests/workflows/`:

### Main Workflows
- ✅ `demultiplex_amplicons` - Demultiplexing workflow
- ✅ `denoise_amplicons_2` - Denoising workflow (3 variants: no refseq, with refseq, no concatenate)
- ✅ `postproc_only` - Post-processing workflow (2 variants: with/without masking)
- ✅ `qc_only` - Quality control only workflow
- ✅ `quality_control` - Quality control workflow (2 variants: with/without postprocessing)
- ✅ `resistance_marker_module` - Resistance marker workflow (2 variants: build info, provided info)

### Workflows Not Tested (Require Panel Information)
- ⚠️ `generate_amplicon_info` - Requires panel_information files not in test data

## Subworkflow Tests

Located in `tests/subworkflows/local/`:

- ✅ `mask_low_complexity_regions` - Low complexity masking (3 variants: both, homo only, tr only)
- ✅ `prepare_reference_sequences` - Reference preparation (2 variants: with genome, with targeted)

### Subworkflows Not Tested (Require Panel Information)
- ⚠️ `concatenate_targeted_reference` - Requires panel_information files not in test data

## E2E Tests

Located in `tests/e2e/`:

- ✅ `Mad4Hatter_basic` - Complete pipeline end-to-end test
- ✅ `Mad4HatterQcOnly_basic` - QC-only workflow end-to-end test
- ✅ `Mad4HatterPostProcessing_basic` - Post-processing workflow end-to-end test

## Test Naming Conventions

### Variant Suffixes
Tests use descriptive suffixes to indicate variants:
- `_no_refseq` - Test without reference sequence (auto-generated)
- `_with_refseq` - Test with provided reference sequence
- `_no_concatenate` - Test without concatenation step
- `_no_masking` - Test without masking
- `_with_postprocess` - Test with postprocessing
- `_no_postprocess` - Test without postprocessing
- `_build_info` - Test that builds resmarker info
- `_provided_info` - Test with provided resmarker info
- `_with_genome` - Test using genome reference
- `_with_targeted` - Test using targeted reference files
- `_both` - Test with both masking types
- `_homo_only` - Test with homopolymer masking only
- `_tr_only` - Test with tandem repeat masking only
- `_basic` - Basic e2e test (success only, no output validation)

## Expected Output Files

Each test has a corresponding `.test.expected.txt` file that contains:
- MD5 checksums for expected outputs
- Format: `output_name=expected_md5_checksum`
- Comments (lines starting with `#`) are ignored

## Running Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run specific category
find tests/modules -name "*.test.json" | xargs -I {} ./tests/run_tests.sh {}
```

## Test Data

All test data is located in `tests/example_data/` and was copied from the Nextflow pipeline tests to ensure consistency.

## Known Limitations

1. **Panel Information Files**: Some tests require `panel_information/` directory files that are not included in test data. These tests are documented but not created.

2. **E2E Test Complexity**: E2E tests are simplified to check for workflow completion only, not specific output validation, due to the complexity of full pipeline runs.

3. **Array Outputs**: Some tests may have array outputs that need special handling in the test runner.

## Maintenance

When adding new tests:
1. Create `.test.json` file with inputs
2. Create `.test.expected.txt` file with MD5 checksums
3. Update this document
4. Ensure test data files exist in `tests/example_data/`

