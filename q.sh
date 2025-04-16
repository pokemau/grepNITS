#!/bin/bash
directory="PhilNITS FE Past Exams"

cd "${directory}" || { echo "Error: Directory not found"; exit 1; }

read -p "Search terms: " input_string

# Split input by | into an array
IFS='|' read -r -a search_terms <<<"$input_string"

# Trim whitespace and validate input
terms=()
for term in "${search_terms[@]}"; do
    trimmed=$(echo "$term" | xargs)
    if [[ -n "$trimmed" ]]; then
        terms+=("$trimmed")
    fi
done

if [[ ${#terms[@]} -eq 0 ]]; then
    echo "Error: No valid search terms provided"
    exit 1
fi

pattern=""
for term in "${terms[@]}"; do
    if [[ -z "$pattern" ]]; then
        pattern="$term"
    else
        pattern="$pattern|$term"
    fi
done

# Store results in an array
declare -a results
found=false
index=1

# Loop through PDF files
for file in *.pdf; do
    [[ ! -e "$file" ]] && continue

    if [[ "$file" == *"answers"* ]]; then
        continue
    fi

    # Capture pdfgrep output
    output=$(pdfgrep -i -H "$pattern" "$file" 2>/dev/null)
    if [[ -n "$output" ]]; then
        found=true
        while IFS= read -r line; do
            results+=("[${index}] ${line}")
            ((index++))
        done <<< "$output"
    fi
done

if ! $found; then
    echo "No matches found for: ${terms[*]}"
    exit 0
fi

# Display results
for result in "${results[@]}"; do
    echo "$result"
done

# Prompt user for selection
read -p "Select files to open (e.g., 1-3,1,6,9,*): " selection

# Process selection
files_to_open=()
if [[ "$selection" == "*" ]]; then
    # Add all files
    for result in "${results[@]}"; do
        filename=$(echo "$result" | cut -d':' -f1 | cut -d' ' -f2-)
        files_to_open+=("$filename")
    done
else
    # Parse comma-separated entries
    IFS=',' read -r -a entries <<<"$selection"
    for entry in "${entries[@]}"; do
        if [[ "$entry" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            for ((i=start; i<=end; i++)); do
                if [[ $i -ge 1 && $i -lt $index ]]; then
                    filename=$(echo "${results[$((i-1))]}" | cut -d':' -f1 | cut -d' ' -f2-)
                    files_to_open+=("$filename")
                fi
            done
        elif [[ "$entry" =~ ^[0-9]+$ ]]; then
            if [[ $entry -ge 1 && $entry -lt $index ]]; then
                filename=$(echo "${results[$((entry-1))]}" | cut -d':' -f1 | cut -d' ' -f2-)
                files_to_open+=("$filename")
            fi
        fi
    done
fi

# Open selected files and their answer counterparts
for file in "${files_to_open[@]}"; do
    # Open the question file
    xdg-open "$file" 2>/dev/null &

    # Generate and open the answer file
    answer_file="${file/Questions/Answer}"
    if [[ -f "$answer_file" ]]; then
        xdg-open "$answer_file" 2>/dev/null &
    fi
done
