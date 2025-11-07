#!/bin/bash
#
# SPDX to CycloneDX Converter
# 
# Convert SPDX JSON files to CycloneDX format and merge them into a single SBOM
#
# Copyright (c) 2025
# Licensed under the MIT License - see LICENSE file for details
#
# Usage: ./convert_spdx_to_cyclonedx.sh [OPTIONS] [spdx_directory] [output_file]
#
# Options:
#   --include-native    Include native packages (build-time only packages)
#                       By default, native packages are excluded from the SBOM
#   -h, --help          Show help message
#

set -e

# Parse command line arguments
INCLUDE_NATIVE=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --include-native)
            INCLUDE_NATIVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [spdx_directory] [output_file]"
            echo ""
            echo "Convert SPDX JSON files to a single CycloneDX SBOM"
            echo ""
            echo "Options:"
            echo "  --include-native    Include native packages (build-time only)"
            echo "                      Default: native packages are excluded"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "Arguments:"
            echo "  spdx_directory      Directory containing SPDX JSON files"
            echo "                      Default: ragnaros-image-core-imx6ull-rfgw4030-20251107091216.spdx"
            echo "  output_file         Output CycloneDX JSON file"
            echo "                      Default: merged-sbom.json"
            echo ""
            echo "Examples:"
            echo "  $0 ./spdx_dir output.json"
            echo "  $0 --include-native ./spdx_dir output.json"
            exit 0
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

# Default values
SPDX_DIR="${1:-ragnaros-image-core-imx6ull-rfgw4030-20251107091216.spdx}"
OUTPUT_FILE="${2:-merged-sbom.json}"
TEMP_DIR=$(mktemp -d)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SPDX to CycloneDX Converter ===${NC}"
echo "SPDX Directory: $SPDX_DIR"
echo "Output File: $OUTPUT_FILE"
echo "Include Native Packages: $INCLUDE_NATIVE"
echo "Temporary Directory: $TEMP_DIR"
echo ""

# Check if SPDX directory exists
if [ ! -d "$SPDX_DIR" ]; then
    echo -e "${RED}Error: Directory '$SPDX_DIR' not found${NC}"
    exit 1
fi

# Check if required dependencies are installed
MISSING_DEPS=()

if ! command -v cyclonedx &> /dev/null; then
    MISSING_DEPS+=("cyclonedx")
fi

if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required dependencies${NC}"
    echo ""
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "${RED}  ✗ $dep${NC}"
        case $dep in
            cyclonedx)
                echo "    Install: https://github.com/CycloneDX/cyclonedx-cli"
                echo "    Or: brew install cyclonedx/cyclonedx/cyclonedx-cli"
                ;;
            jq)
                echo "    Install: https://stedolan.github.io/jq/"
                echo "    Or: apt-get install jq / brew install jq"
                ;;
        esac
        echo ""
    done
    exit 1
fi

echo -e "${GREEN}✓ Dependencies verified (cyclonedx, jq)${NC}"
echo ""

# Find all SPDX JSON files
if [ "$INCLUDE_NATIVE" = true ]; then
    SPDX_FILES=($(find "$SPDX_DIR" -name "*.spdx.json" -type f | sort))
else
    # Exclude native packages (files ending with -native-*.spdx.json or containing -native- in the name)
    SPDX_FILES=($(find "$SPDX_DIR" -name "*.spdx.json" -type f | grep -v "\-native\-" | grep -v "\-native\.spdx\.json$" | sort))
fi

if [ ${#SPDX_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No .spdx.json files found in '$SPDX_DIR'${NC}"
    if [ "$INCLUDE_NATIVE" = false ]; then
        echo -e "${YELLOW}Tip: Use --include-native to include native packages${NC}"
    fi
    exit 1
fi

echo -e "${YELLOW}Found ${#SPDX_FILES[@]} SPDX files${NC}"
if [ "$INCLUDE_NATIVE" = false ]; then
    NATIVE_COUNT=$(find "$SPDX_DIR" -name "*.spdx.json" -type f | grep -E "\-native\-|\-native\.spdx\.json$" | wc -l)
    if [ "$NATIVE_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Excluding $NATIVE_COUNT native packages (use --include-native to include them)${NC}"
    fi
fi
echo ""

# Convert each SPDX file to CycloneDX format
CDX_FILES=()
CONVERTED=0
FAILED=0

echo -e "${GREEN}Converting SPDX files to CycloneDX...${NC}"
for spdx_file in "${SPDX_FILES[@]}"; do
    filename=$(basename "$spdx_file" .spdx.json)
    cdx_file="$TEMP_DIR/${filename}.cdx.json"
    
    echo -n "  Converting: $filename ... "
    
    if cyclonedx convert \
        --input-file "$spdx_file" \
        --output-file "$cdx_file" \
        --input-format spdxjson \
        --output-format json \
        --output-version v1_6 2>&1 >/dev/null; then
        
        echo -e "${GREEN}✓${NC}"
        CDX_FILES+=("$cdx_file")
        CONVERTED=$((CONVERTED + 1))
    else
        echo -e "${RED}✗${NC}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo -e "${YELLOW}Conversion complete: $CONVERTED successful, $FAILED failed${NC}"

# Check if we have any converted files
if [ ${#CDX_FILES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No files were successfully converted${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Merge all CycloneDX files into a single SBOM
echo ""
echo -e "${GREEN}Merging ${#CDX_FILES[@]} CycloneDX files...${NC}"

# Extract base name from directory for the merged BOM
BOM_NAME=$(basename "$SPDX_DIR" .spdx)

# For large numbers of files, merge in batches to avoid command line length limits
BATCH_SIZE=50
TOTAL_FILES=${#CDX_FILES[@]}
BATCH_COUNT=$(( (TOTAL_FILES + BATCH_SIZE - 1) / BATCH_SIZE ))
BATCH_OUTPUTS=()

if [ $TOTAL_FILES -le $BATCH_SIZE ]; then
    # Small number of files, merge directly
    echo "  Merging all files in one operation..."
    if cyclonedx merge \
        --input-files "${CDX_FILES[@]}" \
        --output-file "$OUTPUT_FILE" \
        --output-format json \
        --output-version v1_6 \
        --name "$BOM_NAME" \
        --version "1.0" 2>&1 | grep -v "^Processing"; then
        
        echo -e "${GREEN}✓ Successfully merged into: $OUTPUT_FILE${NC}"
    else
        echo -e "${RED}✗ Merge failed${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
else
    # Large number of files, merge in batches
    echo "  Merging in $BATCH_COUNT batches of up to $BATCH_SIZE files each..."
    
    for ((i=0; i<$BATCH_COUNT; i++)); do
        START=$((i * BATCH_SIZE))
        END=$((START + BATCH_SIZE))
        if [ $END -gt $TOTAL_FILES ]; then
            END=$TOTAL_FILES
        fi
        
        BATCH_FILES=("${CDX_FILES[@]:$START:$BATCH_SIZE}")
        BATCH_OUTPUT="$TEMP_DIR/batch_${i}.json"
        
        echo -n "    Batch $((i+1))/$BATCH_COUNT (files $((START+1))-$END)... "
        
        if cyclonedx merge \
            --input-files "${BATCH_FILES[@]}" \
            --output-file "$BATCH_OUTPUT" \
            --output-format json \
            --output-version v1_6 \
            --name "$BOM_NAME-batch-$i" \
            --version "1.0" 2>&1 | grep -q "Writing output file"; then
            
            echo -e "${GREEN}✓${NC}"
            BATCH_OUTPUTS+=("$BATCH_OUTPUT")
        else
            echo -e "${RED}✗${NC}"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    done
    
    # Final merge of batch outputs
    echo "  Merging batch results into final SBOM..."
    if cyclonedx merge \
        --input-files "${BATCH_OUTPUTS[@]}" \
        --output-file "$OUTPUT_FILE" \
        --output-format json \
        --output-version v1_6 \
        --name "$BOM_NAME" \
        --version "1.0" 2>&1 | grep -v "^Processing"; then
        
        echo -e "${GREEN}✓ Successfully merged into: $OUTPUT_FILE${NC}"
    else
        echo -e "${RED}✗ Final merge failed${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# Clean up temporary directory
echo ""
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

# Fix validation issues - remove empty email addresses and fix invalid URLs
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}Fixing validation issues...${NC}"
    TEMP_FILE="${OUTPUT_FILE}.tmp"
    
    # Remove empty email fields, empty contact arrays, and fix invalid external reference URLs
    jq '
    def fix_url:
        if . == "NOASSERTION" or . == "" then
            null
        elif test(" ") then
            gsub(" "; "%20") | gsub("\\["; "%5B") | gsub("\\]"; "%5D")
        else
            .
        end;

    walk(
        if type == "object" then
            # Fix contact/email issues
            (if has("contact") then
                .contact |= (map(
                    if has("email") and .email == "" then
                        del(.email)
                    else
                        .
                    end
                ) | if . == [] or . == [{}] then null else . end)
            else
                .
            end) |
            if .contact == null then del(.contact) else . end |
            # Fix external references with invalid URLs
            (if has("externalReferences") then
                .externalReferences |= (map(
                    if has("url") then
                        .url |= fix_url |
                        if .url == null then null else . end
                    else
                        .
                    end
                ) | map(select(. != null)) | if length == 0 then null else . end)
            else
                .
            end) |
            if .externalReferences == null then del(.externalReferences) else . end
        else
            .
        end
    )' "$OUTPUT_FILE" > "$TEMP_FILE"
    
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Validation issues fixed${NC}"
fi

# Show file size and component count
if [ -f "$OUTPUT_FILE" ]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    COMPONENT_COUNT=$(jq '[.components // [] | length, (.metadata.component.components // [] | length)] | add' "$OUTPUT_FILE" 2>/dev/null || echo "N/A")
    
    echo ""
    echo -e "${GREEN}=== Summary ===${NC}"
    echo "Output File: $OUTPUT_FILE"
    echo "File Size: $FILE_SIZE"
    echo "Components: $COMPONENT_COUNT"
    
    # Validate the output
    echo ""
    echo -e "${YELLOW}Validating SBOM...${NC}"
    if cyclonedx validate --input-file "$OUTPUT_FILE" --fail-on-errors 2>&1 | grep -q "BOM validated successfully"; then
        echo -e "${GREEN}✓ SBOM is valid!${NC}"
    else
        echo -e "${YELLOW}⚠ Validation warnings exist (non-critical)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Done!${NC}"
fi
