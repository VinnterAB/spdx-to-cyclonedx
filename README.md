# SPDX to CycloneDX Converter

A bash script to convert SPDX JSON files to CycloneDX format and merge them into a single Software Bill of Materials (SBOM). Optimized for Yocto/OpenEmbedded build outputs with automatic validation and DependencyTrack compatibility.

## Features

- ✅ **Batch Conversion**: Converts multiple SPDX JSON files to CycloneDX v1.6 format
- ✅ **Smart Merging**: Automatically merges files in batches to handle large datasets (640+ files)
- ✅ **Native Package Filtering**: Excludes build-time only packages by default
- ✅ **Automatic Validation Fixes**: Cleans up invalid emails, URLs, and other schema violations
- ✅ **DependencyTrack Ready**: Produces validated SBOMs compatible with DependencyTrack
- ✅ **Comprehensive Error Handling**: Clear error messages and dependency checks
- ✅ **Progress Tracking**: Real-time conversion and merge progress indicators

## Requirements

- **cyclonedx-cli** - CycloneDX CLI tool
- **jq** - JSON processor

### Installation

**CycloneDX CLI:**
```bash
# Homebrew (macOS/Linux)
brew install cyclonedx/cyclonedx/cyclonedx-cli

# Or download from: https://github.com/CycloneDX/cyclonedx-cli
```

**jq:**
```bash
# Debian/Ubuntu
apt-get install jq

# macOS
brew install jq

# Or download from: https://stedolan.github.io/jq/
```

## Usage

### Basic Usage

```bash
./convert_spdx_to_cyclonedx.sh [OPTIONS] [spdx_directory] [output_file]
```

### Options

- `--include-native` - Include native packages (build-time only packages). Default: excluded
- `-h, --help` - Show help message

### Examples

**Convert with default settings (excludes native packages):**
```bash
./convert_spdx_to_cyclonedx.sh ./my-spdx-files output.json
```

**Include all packages (including native/build-time):**
```bash
./convert_spdx_to_cyclonedx.sh --include-native ./my-spdx-files output.json
```

**Use default directory and output file:**
```bash
./convert_spdx_to_cyclonedx.sh
```

## Output

The script produces a CycloneDX v1.6 JSON SBOM with:

- All components from SPDX files merged into a single BOM
- Valid IRI-reference URLs (spaces encoded as %20)
- Clean contact information (empty emails removed)
- Valid external references (NOASSERTION values removed)
- Full validation against CycloneDX schema

### Example Output

```
=== SPDX to CycloneDX Converter ===
SPDX Directory: ./ragnaros-image-core-imx6ull-rfgw4030-20251107091216.spdx
Output File: output.json
Include Native Packages: false

✓ Dependencies verified (cyclonedx, jq)

Found 554 SPDX files
Excluding 86 native packages (use --include-native to include them)

Converting SPDX files to CycloneDX...
  Converting: base-files ... ✓
  Converting: busybox ... ✓
  ...

Conversion complete: 554 successful, 0 failed

Merging 554 CycloneDX files...
  Merging in 12 batches of up to 50 files each...
    Batch 1/12 (files 1-50)... ✓
    ...
  Merging batch results into final SBOM...
✓ Successfully merged into: output.json

Cleaning up temporary files...
Fixing validation issues...
✓ Validation issues fixed

=== Summary ===
Output File: output.json
File Size: 1.8M
Components: 1847

Validating SBOM...
✓ SBOM is valid!

Done!
```

## Native Package Filtering

By default, the script excludes "native" packages - these are build-time dependencies that run on the build machine but are not installed on the target system. This is typically the desired behavior for runtime SBOMs.

**Examples of excluded packages:**
- `cmake-native`
- `gcc-native`
- `python3-native`
- Other build tools

Use `--include-native` if you need a complete build-time dependency analysis.

## Validation Fixes

The script automatically fixes common validation issues:

1. **Empty Email Addresses**: Removes empty email strings from contact information
2. **Invalid URLs**:
   - Removes "NOASSERTION" and empty URL values
   - URL-encodes spaces and special characters (e.g., `UnZip 6.0` → `UnZip%206.0`)
3. **Empty Arrays**: Cleans up empty contact and externalReferences arrays

## DependencyTrack Integration

The generated SBOM is fully compatible with DependencyTrack. Simply upload the output JSON file:

```bash
# Using curl
curl -X "POST" "http://dependencytrack-server/api/v1/bom" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -F "project=PROJECT_UUID" \
  -F "bom=@output.json"
```

## Technical Details

### Batch Processing

For large numbers of files (>50), the script:
1. Converts all SPDX files to CycloneDX format
2. Merges files in batches of 50 to avoid command-line length limits
3. Performs a final merge of batch results

### Temporary Files

The script creates a temporary directory for intermediate files, which is automatically cleaned up after completion or on error.

## Troubleshooting

### Missing Dependencies

If you see a dependency error, install the missing tools:

```bash
Error: Missing required dependencies

  ✗ cyclonedx
    Install: https://github.com/CycloneDX/cyclonedx-cli
    Or: brew install cyclonedx/cyclonedx/cyclonedx-cli

  ✗ jq
    Install: https://stedolan.github.io/jq/
    Or: apt-get install jq / brew install jq
```

### No SPDX Files Found

Ensure your SPDX files:
- Are in JSON format
- Have the `.spdx.json` extension
- Are in the specified directory

If all files are native packages, try with `--include-native`.

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Author

Created for converting Yocto/OpenEmbedded SPDX outputs to CycloneDX format.
