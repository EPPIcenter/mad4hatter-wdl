# Test Suite Changelog

## Latest Updates

### Added Missing Tests

#### Workflow Tests
- ✅ `demultiplex_amplicons` - Tests demultiplexing workflow
- ✅ `denoise_amplicons_2` - 3 variants (no refseq, with refseq, no concatenate)
- ✅ `quality_control` - 2 variants (with/without postprocessing)
- ✅ `resistance_marker_module` - 2 variants (build info, provided info)

#### Subworkflow Tests
- ✅ `mask_low_complexity_regions` - 3 variants (both, homo only, tr only)
- ✅ `prepare_reference_sequences` - 2 variants (with genome, with targeted)

#### E2E Tests
- ✅ `Mad4Hatter_basic` - Complete pipeline test
- ✅ `Mad4HatterQcOnly_basic` - QC-only workflow test
- ✅ `Mad4HatterPostProcessing_basic` - Post-processing workflow test

### Test Runner Improvements

1. **Enhanced Variant Name Handling**
   - Added support for many more variant suffixes
   - Improved suffix removal order to handle complex names

2. **Subworkflow Support**
   - Added detection for `subworkflows/local/` directory
   - Maps test files to correct subworkflow WDL files

3. **E2E Test Support**
   - Added detection for `e2e/` directory
   - Maps test files to main workflow files in project root
   - E2E tests only check for success (no output validation)

4. **Array Output Handling**
   - Improved handling of array outputs in test validation
   - Better extraction of file paths from nested structures

5. **Empty Expected Outputs**
   - E2E tests can have empty expected files (success-only tests)
   - Test runner skips validation for empty expected files

### Fixed Issues

1. **Read-Only File System**
   - Fixed `mask_reference_tandem_repeats.wdl` to use `cp` instead of `mv`
   - Resolves Docker volume mounting issues

2. **Missing Reference Inputs**
   - Added `refseq_fasta` to `postproc_only` tests
   - Fixed workflow test failures

3. **Incorrect Parameter Names**
   - Fixed `build_resmarker_info_and_resistance_table` tests to use `resmarkers_info_tsv`

### Test Statistics

- **Before**: 8 module tests + 3 workflow tests = 11 tests
- **After**: 20+ module tests + 10+ workflow tests + 5+ subworkflow tests + 3 e2e tests = 38+ tests

### Files Created

#### Workflow Tests (7 new)
- `tests/workflows/demultiplex_amplicons.test.json`
- `tests/workflows/denoise_amplicons_2_*.test.json` (3 files)
- `tests/workflows/quality_control_*.test.json` (2 files)
- `tests/workflows/resistance_marker_module_*.test.json` (2 files)

#### Subworkflow Tests (5 new)
- `tests/subworkflows/local/mask_low_complexity_regions_*.test.json` (3 files)
- `tests/subworkflows/local/prepare_reference_sequences_*.test.json` (2 files)

#### E2E Tests (3 new)
- `tests/e2e/Mad4Hatter_basic.test.json`
- `tests/e2e/Mad4HatterQcOnly_basic.test.json`
- `tests/e2e/Mad4HatterPostProcessing_basic.test.json`

### Documentation

- Created `TEST_COVERAGE.md` - Comprehensive test coverage documentation
- Created `CHANGELOG.md` - This file
- Updated `README.md` - Added information about new test types

### Known Limitations

1. **Panel Information Files**: Some tests require files from `panel_information/` directory that aren't in test data:
   - `generate_amplicon_info` workflow tests
   - `concatenate_targeted_reference` subworkflow tests

2. **E2E Test Complexity**: E2E tests are simplified to check workflow completion only, not specific outputs, due to the complexity of full pipeline runs.

3. **Test Data Requirements**: Some e2e tests may require additional test data files that need to be verified.

## Next Steps

1. Run full test suite to verify all new tests work
2. Add panel_information files if needed for complete coverage
3. Consider adding more e2e test variants for different parameter combinations
4. Monitor test execution times and optimize if needed

