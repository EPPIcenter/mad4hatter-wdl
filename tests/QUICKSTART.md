# Quick Start Guide for Running Tests

## Prerequisites

1. Install miniwdl:
   ```bash
   pip install miniwdl
   ```

2. Ensure Docker is running and the image is available:
   ```bash
   docker pull eppicenter/mad4hatter:develop
   ```

## Run All Tests

```bash
cd /path/to/mad4hatter-wdl
./tests/run_tests.sh
```

## Run a Single Test

```bash
# Example: Test build_alleletable module
miniwdl run modules/local/build_alleletable.wdl \
  -i tests/modules/local/build_alleletable.test.json \
  --dir test_outputs
```

## Update Expected MD5 Checksums

If outputs change legitimately, update the expected checksums:

1. Run the test to generate outputs
2. Find the output file in `tests/test_results/<test_name>/workdir/outputs/`
3. Calculate MD5:
   ```bash
   # macOS
   md5 -q path/to/output_file.txt
   
   # Linux
   md5sum path/to/output_file.txt | cut -d' ' -f1
   ```
4. Update the corresponding `.test.expected.txt` file

## Troubleshooting

- **Test fails with "miniwdl not found"**: Install with `pip install miniwdl`
- **Docker errors**: Ensure Docker is running and image is pulled
- **File not found**: Check that `tests/example_data/` contains all required files
- **MD5 mismatch**: See "Update Expected MD5 Checksums" above

For more details, see [README.md](README.md).

