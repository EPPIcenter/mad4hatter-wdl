# Missing Tests Documentation

## Overview

Some tests from the Nextflow pipeline were not initially created because they require files that may not be available in the `tests/example_data/` directory, or because the WDL implementation differs from Nextflow.

## Tests Now Added

The following tests have been added:

1. **create_primer_files** - Tests primer file generation from amplicon info
2. **create_reference_from_genomes** - Tests reference sequence extraction from genome files
3. **mask_reference_homopolymers** - Tests homopolymer masking
4. **mask_sequences** - Tests sequence masking (4 variants: homo, tr, both, hapseq)
5. **align_to_reference_and_filter_asvs** - Tests alignment and ASV filtering (combined task in WDL)
6. **postprocess_coverage** - Tests coverage postprocessing
7. **build_targeted_reference** - Tests targeted reference merging (2 variants)

## Tests That May Need Additional Setup

### build_amplicon_info

The Nextflow tests for `build_amplicon_info` use files from `panel_information/` directory which may not be available in the test example_data. The tests require:
- `panel_information/D1.1/D1.1_amplicon_info.tsv`
- `panel_information/R1.2/R1.2_amplicon_info.tsv`
- `panel_information/R2.1/R2.1_amplicon_info.tsv`

**Status**: Not created - requires panel_information files

**To add**: Copy panel_information files to tests/example_data or create test-specific versions

### build_resmarker_info

In the WDL version, `build_resmarker_info` functionality is integrated into `build_resmarker_info_and_resistance_table` task. The separate `build_resmarker_info` process from Nextflow doesn't exist as a standalone task in WDL.

**Status**: Covered by `build_resmarker_info_and_resistance_table` tests

## Test Coverage Summary

### Module Tests Created: 20+ tests
- ✅ build_alleletable
- ✅ build_pseudocigar (3 variants)
- ✅ build_resmarker_info_and_resistance_table (2 variants)
- ✅ collapse_concatenated_reads (2 variants)
- ✅ preprocess_coverage
- ✅ create_primer_files
- ✅ create_reference_from_genomes
- ✅ mask_reference_homopolymers
- ✅ mask_sequences (4 variants)
- ✅ align_to_reference_and_filter_asvs
- ✅ postprocess_coverage
- ✅ build_targeted_reference (2 variants)

### Workflow Tests Created: 3 tests
- ✅ postproc_only (2 variants)
- ✅ qc_only

### Tests Not Created (Require Additional Files)
- ⚠️ build_amplicon_info (requires panel_information files)

## Notes

- The WDL version combines some Nextflow processes (e.g., `align_to_reference` + `filter_asvs` = `align_to_reference_and_filter_asvs`)
- Some tests use panel_information files that are part of the main pipeline but not included in test data
- All tests use MD5 checksums for output validation, matching the Nextflow nf-test approach

