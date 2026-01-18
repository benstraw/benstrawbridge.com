#!/bin/bash

# Script to check all links in the Hugo links section

echo "Extracting all URLs from links section..."

# Create a temporary file to store results
RESULTS_FILE="link_check_results.md"

# Start the results file
cat > "$RESULTS_FILE" << 'EOF'
# Link Check Report

This report shows the status of all links in the links section.

## Summary

EOF

# Arrays to track statistics
declare -a all_links
declare -a working_links
declare -a error_links
declare -a redirected_links

# Function to check a URL
check_url() {
    local url="$1"
    local timeout=10

    # Use curl to check the URL
    # -L follows redirects
    # -I gets headers only
    # -s silent mode
    # -w writes out format string
    # --max-time sets timeout
    local response=$(curl -L -I -s -w "%{http_code}|%{url_effective}" --max-time "$timeout" "$url" 2>&1)

    # Extract status code and final URL
    local status_code=$(echo "$response" | tail -1 | cut -d'|' -f1)
    local final_url=$(echo "$response" | tail -1 | cut -d'|' -f2)

    # Determine if redirected
    local redirected="false"
    if [ "$url" != "$final_url" ] && [ -n "$final_url" ]; then
        redirected="true"
    fi

    # Return result
    echo "${status_code}|${redirected}|${final_url}"
}

# Extract URLs from all markdown files in links section
echo ""
echo "Scanning files for links..."

# Process each subsection
for section_dir in content/links/*/; do
    section_name=$(basename "$section_dir")

    # Skip if it's just content/links/ itself
    if [ "$section_name" == "*" ]; then
        continue
    fi

    index_file="${section_dir}index.md"

    if [ ! -f "$index_file" ]; then
        continue
    fi

    echo "Processing section: $section_name"

    # Add section header to results
    echo "" >> "$RESULTS_FILE"
    echo "## $section_name" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"

    # Extract links from the file
    while IFS= read -r line; do
        # Extract URL from markdown link format [text](url)
        if [[ $line =~ \[([^\]]+)\]\(([^)]+)\) ]]; then
            link_text="${BASH_REMATCH[1]}"
            url="${BASH_REMATCH[2]}"

            # Only process http/https URLs
            if [[ $url =~ ^https?:// ]]; then
                echo "  Checking: $url"

                all_links+=("$url")

                # Check the URL
                result=$(check_url "$url")
                status_code=$(echo "$result" | cut -d'|' -f1)
                redirected=$(echo "$result" | cut -d'|' -f2)
                final_url=$(echo "$result" | cut -d'|' -f3)

                # Categorize result
                if [ "$status_code" == "200" ] || [ "$status_code" == "301" ] || [ "$status_code" == "302" ]; then
                    working_links+=("$url")
                    if [ "$redirected" == "true" ]; then
                        redirected_links+=("$url")
                        echo "| ✓ | [$link_text]($url) | $status_code | Redirected to: $final_url |" >> "$RESULTS_FILE"
                    else
                        echo "| ✓ | [$link_text]($url) | $status_code | OK |" >> "$RESULTS_FILE"
                    fi
                elif [ "$status_code" == "000" ] || [ -z "$status_code" ]; then
                    error_links+=("$url")
                    echo "| ✗ | [$link_text]($url) | - | Connection failed or timeout |" >> "$RESULTS_FILE"
                else
                    error_links+=("$url")
                    echo "| ✗ | [$link_text]($url) | $status_code | Error |" >> "$RESULTS_FILE"
                fi
            fi
        fi
    done < "$index_file"
done

# Calculate statistics
total_links=${#all_links[@]}
working_count=${#working_links[@]}
error_count=${#error_links[@]}
redirect_count=${#redirected_links[@]}

# Update summary section
summary="
**Statistics:**
- Total links checked: $total_links
- Working links: $working_count ($(( working_count * 100 / total_links ))%)
- Failed links: $error_count ($(( error_count * 100 / total_links ))%)
- Redirected links: $redirect_count

**Legend:**
- ✓ = Working
- ✗ = Failed

---
"

# Insert summary at the right place
sed -i "/## Summary/a\\$summary" "$RESULTS_FILE"

echo ""
echo "=================================================="
echo "Link Check Complete!"
echo "=================================================="
echo "Total links: $total_links"
echo "Working: $working_count"
echo "Failed: $error_count"
echo "Redirected: $redirect_count"
echo ""
echo "Full report saved to: $RESULTS_FILE"
