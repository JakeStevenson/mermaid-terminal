#!/bin/bash
# Renders a Mermaid diagram as ASCII art in the terminal
# Usage: render_mermaid.sh <mermaid_file> [options]
#        echo "graph LR; A-->B" | render_mermaid.sh - [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find mermaid-ascii binary
find_mermaid_ascii() {
    if command -v mermaid-ascii &> /dev/null; then
        echo "mermaid-ascii"
        return 0
    elif [ -x "$HOME/.local/bin/mermaid-ascii" ]; then
        echo "$HOME/.local/bin/mermaid-ascii"
        return 0
    fi
    return 1
}

# Auto-install if not found
MERMAID_BIN=$(find_mermaid_ascii) || {
    echo "mermaid-ascii not found. Installing..." >&2
    bash "$SCRIPT_DIR/install_mermaid_ascii.sh" >&2
    MERMAID_BIN=$(find_mermaid_ascii) || {
        echo "Installation failed. Please install manually." >&2
        exit 1
    }
}

# Get terminal width (default to 120 if unavailable)
TERM_WIDTH=$(tput cols 2>/dev/null || echo 120)

# Fix mermaid-ascii bug that duplicates output
dedupe_output() {
    local output="$1"
    local lines=$(echo "$output" | wc -l)
    local half=$((lines / 2))

    if [ "$half" -gt 0 ] && [ "$((half * 2))" -eq "$lines" ]; then
        local first_hash=$(echo "$output" | head -n "$half" | md5sum | cut -d' ' -f1)
        local second_hash=$(echo "$output" | tail -n "$half" | md5sum | cut -d' ' -f1)
        if [ "$first_hash" = "$second_hash" ]; then
            echo "$output" | head -n "$half"
            return
        fi
    fi
    echo "$output"
}

# Check if Unicode output has alignment issues
# Returns 0 if alignment looks broken, 1 if OK
check_unicode_alignment() {
    local output="$1"

    # Get lines containing box-drawing characters
    local box_lines=$(echo "$output" | grep -n '[│┌┐└┘├┤┬┴┼]' | head -20)
    [ -z "$box_lines" ] && return 1  # No box chars, assume OK

    # Check if line lengths are consistent for adjacent box-drawing lines
    # Misaligned Unicode often causes jagged line lengths
    local prev_len=0
    local inconsistent=0

    while IFS= read -r line; do
        # Get actual line content (after line number)
        local content=$(echo "$line" | cut -d: -f2-)
        local len=${#content}

        # If previous line exists and lengths differ significantly on box lines
        if [ "$prev_len" -gt 0 ]; then
            local diff=$((len - prev_len))
            [ "$diff" -lt 0 ] && diff=$((-diff))
            # Allow small differences, but flag large ones
            if [ "$diff" -gt 3 ]; then
                inconsistent=$((inconsistent + 1))
            fi
        fi
        prev_len=$len
    done <<< "$box_lines"

    # If more than 2 inconsistencies, likely misaligned
    [ "$inconsistent" -gt 2 ] && return 0
    return 1
}

# Analyze diagram complexity and calculate optimal spacing
calculate_spacing() {
    local file="$1"
    local content=$(cat "$file")

    # Count nodes (rough estimate: look for [...], (...), {...} patterns)
    local node_count=$(echo "$content" | grep -oE '\[[^\]]+\]|\([^\)]+\)|\{[^\}]+\}' | wc -l)

    # Find longest label
    local max_label_len=$(echo "$content" | grep -oE '\[[^\]]+\]|\([^\)]+\)|\{[^\}]+\}' | \
        sed 's/[][]//g; s/[()]//g; s/[{}]//g' | \
        awk '{ print length }' | sort -rn | head -1)
    max_label_len=${max_label_len:-10}

    # Check if horizontal flow (LR/RL tends to be wider)
    local is_horizontal=$(echo "$content" | grep -qiE 'graph\s+(LR|RL)' && echo 1 || echo 0)

    # Estimate width: nodes * (label_width + spacing + box_padding)
    # Box adds ~4 chars, spacing between nodes
    local estimated_width
    if [ "$is_horizontal" = "1" ]; then
        estimated_width=$((node_count * (max_label_len + 20)))
    else
        # TD/TB layouts are narrower but still can spread with branches
        estimated_width=$((node_count * (max_label_len + 10) / 2))
    fi

    # Calculate spacing based on how much room we have
    local available_ratio=$((TERM_WIDTH * 100 / (estimated_width + 1)))

    if [ "$available_ratio" -ge 150 ]; then
        # Plenty of room - use comfortable spacing
        echo "6 4"
    elif [ "$available_ratio" -ge 100 ]; then
        # Should fit - use moderate spacing
        echo "4 3"
    elif [ "$available_ratio" -ge 70 ]; then
        # Tight - use compact spacing
        echo "2 2"
    else
        # Very tight - minimum spacing
        echo "1 1"
    fi
}

# Parse arguments
INPUT=""
EXTRA_ARGS=""
MANUAL_SPACING=0
MANUAL_ASCII=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -)
            INPUT="-"
            shift
            ;;
        -f|--file)
            INPUT="$2"
            shift 2
            ;;
        -x|-y)
            # User specified spacing manually
            MANUAL_SPACING=1
            EXTRA_ARGS="$EXTRA_ARGS $1 $2"
            shift 2
            ;;
        --ascii)
            MANUAL_ASCII=1
            EXTRA_ARGS="$EXTRA_ARGS $1"
            shift
            ;;
        *)
            if [ -z "$INPUT" ] && [ -f "$1" ]; then
                INPUT="$1"
            else
                EXTRA_ARGS="$EXTRA_ARGS $1"
            fi
            shift
            ;;
    esac
done

# Handle stdin - save to temp file for analysis
TEMP_FILE=""
if [ "$INPUT" = "-" ]; then
    TEMP_FILE=$(mktemp /tmp/mermaid.XXXXXX)
    cat > "$TEMP_FILE"
    INPUT="$TEMP_FILE"
fi

if [ -z "$INPUT" ]; then
    echo "Usage: render_mermaid.sh <file.mermaid> [options]"
    echo "       echo 'graph LR; A-->B' | render_mermaid.sh - [options]"
    echo ""
    echo "Options are passed to mermaid-ascii:"
    echo "  -x <int>   Horizontal spacing (default: auto-calculated)"
    echo "  -y <int>   Vertical spacing (default: auto-calculated)"
    echo "  -p <int>   Border padding (default: 1)"
    echo "  --ascii    Use pure ASCII (no Unicode)"
    echo ""
    echo "Spacing is automatically adjusted based on terminal width ($TERM_WIDTH cols)"
    exit 1
fi

# Calculate spacing unless manually specified
if [ "$MANUAL_SPACING" = "0" ]; then
    read X_SPACING Y_SPACING <<< $(calculate_spacing "$INPUT")
    SPACING_ARGS="-x $X_SPACING -y $Y_SPACING -p 1"
else
    SPACING_ARGS="-p 1"
fi

# Render the diagram
USE_ASCII=0
[ "$MANUAL_ASCII" = "1" ] && USE_ASCII=1

OUTPUT=$($MERMAID_BIN -f "$INPUT" $SPACING_ARGS $EXTRA_ARGS 2>&1) || {
    echo "Render failed. Try simplifying the diagram." >&2
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
}
OUTPUT=$(dedupe_output "$OUTPUT")

# Check for Unicode alignment issues and fall back to ASCII if needed
if [ "$USE_ASCII" = "0" ] && check_unicode_alignment "$OUTPUT"; then
    USE_ASCII=1
    OUTPUT=$($MERMAID_BIN -f "$INPUT" $SPACING_ARGS $EXTRA_ARGS --ascii 2>&1) || true
    OUTPUT=$(dedupe_output "$OUTPUT")
fi

# Check output width
OUTPUT_WIDTH=$(echo "$OUTPUT" | awk '{ print length }' | sort -rn | head -1)

if [ "$OUTPUT_WIDTH" -gt "$TERM_WIDTH" ] && [ "$MANUAL_SPACING" = "0" ]; then
    # Try once more with minimum spacing
    ASCII_FLAG=""
    [ "$USE_ASCII" = "1" ] && ASCII_FLAG="--ascii"
    OUTPUT=$($MERMAID_BIN -f "$INPUT" -x 1 -y 1 -p 0 $EXTRA_ARGS $ASCII_FLAG 2>&1) || true
    OUTPUT=$(dedupe_output "$OUTPUT")
    OUTPUT_WIDTH=$(echo "$OUTPUT" | awk '{ print length }' | sort -rn | head -1)

    if [ "$OUTPUT_WIDTH" -gt "$TERM_WIDTH" ]; then
        echo "$OUTPUT"
        echo "" >&2
        echo "Note: Diagram is ${OUTPUT_WIDTH} cols wide (terminal: ${TERM_WIDTH}). Use 'less -S' to scroll." >&2
    else
        echo "$OUTPUT"
    fi
else
    echo "$OUTPUT"
fi

# Cleanup
[ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
exit 0
