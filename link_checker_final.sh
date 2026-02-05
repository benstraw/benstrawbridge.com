#!/bin/bash
# Comprehensive link checker for Hugo links section
# Generates a detailed markdown report with status for each link

set -e

OUTPUT_FILE="LINK_CHECK_REPORT.md"
TEMP_FILE=$(mktemp)

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "Link Checker for BenStrawbridge.com Links Section"
echo "=================================================="
echo ""

# Initialize counters
total_links=0
working_links=0
failed_links=0
redirected_links=0
timeout_links=0

# Start the markdown report
cat > "$OUTPUT_FILE" << 'EOF'
# Link Check Report

Generated: $(date +"%Y-%m-%d %H:%M:%S")

This report shows the status of all external links in the `/content/links` section.

## Summary

EOF

# Function to check a single URL
check_url() {
    local url="$1"
    local timeout=10

    # Use curl with various flags
    # -L: follow redirects
    # -I: fetch headers only
    # -s: silent
    # -S: show errors
    # -w: write-out format
    # --max-time: maximum time allowed
    # -A: user agent

    local curl_output
    curl_output=$(curl -L -I -s -S \
        -A "Mozilla/5.0 (compatible; LinkChecker/1.0)" \
        -w "\n%{http_code}|%{url_effective}|%{redirect_url}" \
        --max-time "$timeout" \
        "$url" 2>&1 | tail -n 1)

    echo "$curl_output"
}

# Function to process a section file
process_section() {
    local section_file="$1"
    local section_name=$(basename $(dirname "$section_file"))

    echo "Processing section: $section_name"

    # Add section header to report
    echo "" >> "$OUTPUT_FILE"
    # Capitalize first letter (bash 3.2 compatible)
    section_title="$(echo "${section_name:0:1}" | tr '[:lower:]' '[:upper:]')${section_name:1}"
    echo "## $section_title" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "| Status | Link | URL | HTTP Code | Notes |" >> "$OUTPUT_FILE"
    echo "|--------|------|-----|-----------|-------|" >> "$OUTPUT_FILE"

    # Extract links from the file
    local in_frontmatter=false
    local line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip frontmatter
        if [[ $line == "+++" ]]; then
            if [ "$in_frontmatter" = false ]; then
                in_frontmatter=true
            else
                in_frontmatter=false
            fi
            continue
        fi

        if [ "$in_frontmatter" = true ]; then
            continue
        fi

        # Extract markdown links: [text](url)
        link_regex='\[([^]]+)\]\(([^)]+)\)'
        if [[ $line =~ $link_regex ]]; then
            link_text="${BASH_REMATCH[1]}"
            url="${BASH_REMATCH[2]}"

            # Only process http/https URLs
            if [[ $url =~ ^https?:// ]]; then
                total_links=$((total_links + 1))

                echo -n "  [$total_links] Checking: ${url:0:60}... "

                # Check the URL
                result=$(check_url "$url")

                if [ $? -eq 0 ] && [ -n "$result" ]; then
                    http_code=$(echo "$result" | cut -d'|' -f1)
                    final_url=$(echo "$result" | cut -d'|' -f2)
                    redirect_url=$(echo "$result" | cut -d'|' -f3)

                    # Determine status
                    if [[ $http_code =~ ^2[0-9]{2}$ ]]; then
                        # 2xx success
                        working_links=$((working_links + 1))

                        if [ -n "$redirect_url" ] && [ "$url" != "$final_url" ]; then
                            redirected_links=$((redirected_links + 1))
                            echo -e "${YELLOW}✓ $http_code (redirected)${NC}"
                            echo "| ✓ | $link_text | \`$url\` | $http_code | Redirects to: $final_url |" >> "$OUTPUT_FILE"
                        else
                            echo -e "${GREEN}✓ $http_code${NC}"
                            echo "| ✓ | $link_text | \`$url\` | $http_code | OK |" >> "$OUTPUT_FILE"
                        fi
                    elif [[ $http_code =~ ^3[0-9]{2}$ ]]; then
                        # 3xx redirect (should be followed by curl -L, but noting it)
                        working_links=$((working_links + 1))
                        redirected_links=$((redirected_links + 1))
                        echo -e "${YELLOW}✓ $http_code (redirect)${NC}"
                        echo "| ✓ | $link_text | \`$url\` | $http_code | Redirect |" >> "$OUTPUT_FILE"
                    elif [[ $http_code =~ ^4[0-9]{2}$ ]] || [[ $http_code =~ ^5[0-9]{2}$ ]]; then
                        # 4xx client error or 5xx server error
                        failed_links=$((failed_links + 1))
                        echo -e "${RED}✗ $http_code${NC}"
                        echo "| ✗ | $link_text | \`$url\` | $http_code | Error |" >> "$OUTPUT_FILE"
                    else
                        # Unknown/other
                        failed_links=$((failed_links + 1))
                        echo -e "${RED}✗ Unknown ($http_code)${NC}"
                        echo "| ✗ | $link_text | \`$url\` | $http_code | Unknown response |" >> "$OUTPUT_FILE"
                    fi
                else
                    # Connection failed or timeout
                    timeout_links=$((timeout_links + 1))
                    failed_links=$((failed_links + 1))
                    echo -e "${RED}✗ Timeout/Connection failed${NC}"
                    echo "| ✗ | $link_text | \`$url\` | - | Connection timeout or failed |" >> "$OUTPUT_FILE"
                fi
            fi
        fi

        # Also check for plain URLs (not in markdown format)
        if [[ $line =~ ^-[[:space:]]+(https?://[^[:space:]]+) ]]; then
            url="${BASH_REMATCH[1]}"

            total_links=$((total_links + 1))

            echo -n "  [$total_links] Checking: ${url:0:60}... "

            result=$(check_url "$url")

            if [ $? -eq 0 ] && [ -n "$result" ]; then
                http_code=$(echo "$result" | cut -d'|' -f1)

                if [[ $http_code =~ ^[23][0-9]{2}$ ]]; then
                    working_links=$((working_links + 1))
                    echo -e "${GREEN}✓ $http_code${NC}"
                    echo "| ✓ | (plain URL) | \`$url\` | $http_code | OK |" >> "$OUTPUT_FILE"
                else
                    failed_links=$((failed_links + 1))
                    echo -e "${RED}✗ $http_code${NC}"
                    echo "| ✗ | (plain URL) | \`$url\` | $http_code | Error |" >> "$OUTPUT_FILE"
                fi
            else
                timeout_links=$((timeout_links + 1))
                failed_links=$((failed_links + 1))
                echo -e "${RED}✗ Timeout${NC}"
                echo "| ✗ | (plain URL) | \`$url\` | - | Connection timeout |" >> "$OUTPUT_FILE"
            fi
        fi
    done < "$section_file"
}

# Find and process all section index files
for section_file in content/links/*/index.md; do
    if [ -f "$section_file" ]; then
        process_section "$section_file"
    fi
done

# Calculate percentages
if [ $total_links -gt 0 ]; then
    working_pct=$((working_links * 100 / total_links))
    failed_pct=$((failed_links * 100 / total_links))
else
    working_pct=0
    failed_pct=0
fi

# Generate summary statistics
summary="
**Total Links Checked:** $total_links

**Results:**
- ✓ **Working:** $working_links ($working_pct%)
- ✗ **Failed:** $failed_links ($failed_pct%)
- 🔄 **Redirected:** $redirected_links
- ⏱️ **Timeouts:** $timeout_links

**Status Codes:**
- 2xx (Success): Indicates the link is working properly
- 3xx (Redirect): The link redirects to another URL
- 4xx (Client Error): Usually 404 Not Found, page doesn't exist
- 5xx (Server Error): Server-side issue
- Timeout: Connection failed or took too long

---
"

# Insert summary into the report
# Use perl for reliable multi-line insertion on macOS
perl -i -pe '$_ .= "'"$summary"'\n" if /^## Summary$/' "$OUTPUT_FILE"

# Print summary to console
echo ""
echo "=================================================="
echo "Link Check Complete!"
echo "=================================================="
echo "Total links checked: $total_links"
echo -e "${GREEN}Working: $working_links ($working_pct%)${NC}"
echo -e "${RED}Failed: $failed_links ($failed_pct%)${NC}"
echo -e "${YELLOW}Redirected: $redirected_links${NC}"
echo -e "${YELLOW}Timeouts: $timeout_links${NC}"
echo ""
echo "Full report saved to: $OUTPUT_FILE"
echo ""

# Clean up
rm -f "$TEMP_FILE"

exit 0
