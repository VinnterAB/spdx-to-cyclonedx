# SPDX to CycloneDX Converter

A bash script to convert SPDX JSON files to CycloneDX format and merge them into a single Software Bill of Materials (SBOM). Optimized for Yocto/OpenEmbedded build outputs with automatic validation and DependencyTrack compatibility.

## Features

- **Batch Conversion**: Convert multiple SPDX JSON files to CycloneDX format
- **Smart Merging**: Automatically merge hundreds of CycloneDX files into a single SBOM
- **Automatic Cleanup**: Remove batch merge metadata and duplicate components
- **Package Filtering**:
  - Exclude native packages (build-time only) by default
  - Filter file-type components (not CVE-scannable) by default
  - Filter source components without version (not CVE-scannable) by default
- **Validation Fixes**: Automatically fix common validation issues for DependencyTrack compatibility
- **PURL Generation**: Automatically generate Package URLs for vulnerability scanning
- **Progress Tracking**: Clear progress indicators during conversion and merging## Requirements

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

### Options

- `--include-native`: Include native packages (build-time only packages)
  - Default: native packages are excluded from the SBOM
  - Native packages typically end with `-native` and are only used during the build process

- `--include-files`: Include file-type components
  - Default: file components are excluded
  - File-type components cannot be scanned for CVEs and significantly increase SBOM size

- `--include-source`: Include source components without version
  - Default: source components without version are excluded
  - Source components (typically named `*-source-*`) without version information cannot be scanned for CVEs

- `-h, --help`: Display help message with usage information

### Examples

**Convert with default settings (excludes native packages and files):**
```bash
./convert_spdx_to_cyclonedx.sh ./my-spdx-files output.json
```

**Include all packages (including native/build-time):**
```bash
./convert_spdx_to_cyclonedx.sh --include-native ./my-spdx-files output.json
```

**Include file-type components:**
```bash
./convert_spdx_to_cyclonedx.sh --include-files ./my-spdx-files output.json
```

**Include source components:**
```bash
./convert_spdx_to_cyclonedx.sh --include-source ./my-spdx-files output.json
```

**Include everything (native packages, files, and source components):**
```bash
./convert_spdx_to_cyclonedx.sh --include-native --include-files --include-source ./my-spdx-files output.json
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
SPDX Directory: ./yocto-image-core-spdx
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

## Component Filtering

### Native Package Filtering

By default, the script excludes "native" packages - these are build-time dependencies that run on the build machine but are not installed on the target system. This is typically the desired behavior for runtime SBOMs.

**Examples of excluded packages:**
- `cmake-native`
- `gcc-native`
- `python3-native`
- Other build tools

Use `--include-native` if you need a complete build-time dependency analysis.

### File Component Filtering

By default, the script excludes file-type components. These are individual files that:
- Cannot be scanned for CVEs (no version information)
- Significantly increase SBOM size without adding security value
- Make vulnerability analysis slower in tools like DependencyTrack

**Impact on typical Yocto build (e.g., 640 SPDX files):**
- **With --include-files**: ~2,025 components (1,574 files + 451 packages)
- **Without --include-files** (default): ~451 components (only libraries and applications)
- **Size reduction**: ~77% smaller SBOM

Use `--include-files` if you need complete file-level inventory for compliance purposes.

### Source Component Filtering

By default, the script excludes source components that lack version information. These are typically source archive references (e.g., `busybox-source-1`, `glibc-source-1`) that:
- Cannot be scanned for CVEs (missing version information)
- Cannot generate valid PURLs (PURL spec requires version)
- Represent source archives rather than runtime components

Use `--include-source` if you need source archive references for compliance tracking.

## Package URL (PURL) Generation

The script automatically generates [Package URLs (PURLs)](https://github.com/package-url/purl-spec) for all components with a name and version. PURLs are essential for vulnerability scanning in DependencyTrack and other security tools.

### PURL Format

The script intelligently generates PURLs based on package naming conventions:

| Package Pattern | PURL Type | Example |
|----------------|-----------|---------|
| `python3-*`, `py-*` | `pkg:pypi/` | `pkg:pypi/requests@2.28.0` |
| `node-*`, `npm-*` | `pkg:npm/` | `pkg:npm/express@4.18.0` |
| `perl-*` | `pkg:cpan/` | `pkg:cpan/JSON@4.10` |
| `ruby-*`, `gem-*` | `pkg:gem/` | `pkg:gem/rails@7.0.0` |
| `go-*`, `golang-*` | `pkg:golang/` | `pkg:golang/gin@1.9.0` |
| `rust-*`, `cargo-*` | `pkg:cargo/` | `pkg:cargo/serde@1.0.0` |
| `php-*` | `pkg:composer/` | `pkg:composer/symfony@6.2.0` |
| `maven-*`, `java-*` | `pkg:maven/` | `pkg:maven/spring-boot@3.0.0` |
| `kernel-X.Y.Z-*` | `pkg:generic/linux@` | `pkg:generic/linux@6.6` |
| All others (Yocto packages) | `pkg:generic/` | `pkg:generic/busybox@1.36.1` |

### Why PURLs Matter

**Yocto/OpenEmbedded SPDX files do not include CPE or PURL information by default.** This script solves that problem by:

1. **Enabling Vulnerability Scanning**: DependencyTrack requires either CPE or PURL to match components against vulnerability databases (NVD, OSS Index, GitHub Advisories)
2. **Supporting Multiple Analyzers**:
   - **Internal Analyzer**: Uses PURLs to match against NVD, GitHub Advisories, OSV
   - **OSS Index**: Requires PURLs for Sonatype's vulnerability database
   - **Snyk**: Uses PURLs for commercial vulnerability scanning
3. **Generic PURL Coverage**: For Yocto/OpenEmbedded packages without specific ecosystem types, `pkg:generic/` PURLs still enable basic matching
4. **Linux Kernel Detection**: Automatically detects Yocto kernel packages (e.g., `kernel-6.6.101-dirty`) and generates proper Linux kernel PURLs (`pkg:generic/linux@6.6.101`) for accurate CVE matching

**Without PURLs**, DependencyTrack cannot perform vulnerability analysis on your components.

### Linux Kernel Special Handling

Yocto/OpenEmbedded generates kernel packages with names like `kernel-6.6.101-dirty` and version `6.6`. The script automatically:
- Detects kernel packages by name pattern (`kernel-X.Y.Z-*`)
- Uses the component's version field for the PURL
- Generates a Linux-specific PURL: `pkg:generic/linux@6.6`
- Enables DependencyTrack to match against Linux kernel CVEs

**Example transformation:**
- **Yocto package**: `kernel-6.6.101-dirty` version `6.6`
- **Generated PURL**: `pkg:generic/linux@6.6`
- **Result**: Accurate CVE scanning for Linux kernel vulnerabilities

## Automatic Cleanup

The script automatically cleans up artifacts and duplicates created during the merge process:

### Batch Merge Metadata Removal

When merging large numbers of files (>50), the script processes files in batches. The CycloneDX merge tool creates metadata components for each batch (e.g., `yocto-image-core-batch-0`, `yocto-image-core-batch-1`, etc.). These are artifacts of the merge process and not actual software components, so they are automatically removed.

**Example Impact:**
- Batch metadata components removed: 12 (from 12 batches)

### Deduplication

The CycloneDX merge operation can create duplicate component entries when the same package appears in multiple SPDX files. The script automatically deduplicates components based on `name@version`, keeping only the first occurrence of each unique component.

This ensures that DependencyTrack doesn't need to perform its own deduplication during import, making the upload process cleaner and faster.

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

Created by Vinnter AB, Sweden. www.vinnter.se
