#!/bin/bash
set -e

echo "🔍 Checking Markdown and MDX files for broken links (404 only)..."

declare -A urlLocations

# 1. Extract URLs
echo "🔗 Extracting URLs..."
find . -type f \( -iname "*.md" -o -iname "*.mdx" \) -exec awk '
{
    line = $0;
    while (match(line, /\[[^]]+\]\((https?:\/\/[^)]+)\)/, arr)) {
        print FILENAME ":" FNR ":" arr[1];
        line = substr(line, RSTART + RLENGTH);
    }
}
' {} + > extracted_links.txt

# 2. Store URL locations
while IFS=: read -r file line url; do
    [[ -n "$url" ]] && urlLocations["$url"]="${file}:${line}"
done < extracted_links.txt

# 3. Deduplicate URLs
echo "${!urlLocations[@]}" | tr ' ' '\n' > url_list.txt

# 4. Check URLs
echo "🚀 Checking URLs (only 404 errors will be reported)..."
declare -A errorInfo

cat url_list.txt | xargs -P 4 -I {} bash -c '
    status=$(curl -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0 Safari/537.36" \
              -L -o /dev/null -s -w "%{http_code}" "{}")
    if [[ "$status" -eq 404 ]]; then
        echo "❌ {} (Status: $status)"
        echo "{} $status" >> invalid_urls_tmp.txt
    else
        echo "✅ {} (Status: $status)"
    fi
'

# 5. Collect invalid URLs
if [[ -f invalid_urls_tmp.txt ]]; then
    while IFS=' ' read -r url status; do
        errorInfo["$url"]="Status: $status | Location: ${urlLocations[$url]}"
    done < invalid_urls_tmp.txt
    rm invalid_urls_tmp.txt
fi

# 6. Print summary
echo
if [ ${#errorInfo[@]} -gt 0 ]; then
    echo "‼️ Found 404 URLs:"
    echo "────────────────────────────────────────────"
    for url in "${!errorInfo[@]}"; do
        echo "🔗 $url"
        echo "   └─ ${errorInfo[$url]}"
    done
    echo "::warning::Some links returned 404. See logs above."
else
    echo "🎉 All links are valid (no 404 errors)."
fi

rm extracted_links.txt url_list.txt
