# mermaid-terminal

A Claude Code skill that renders Mermaid diagrams as ASCII art directly in the terminal.

## Overview

This skill enables Claude Code to visualize diagrams when explaining processes, workflows, architectures, and sequences. Instead of describing relationships in text, Claude can render actual diagrams that display in your terminal.

## Installation

Copy the `mermaid-terminal` directory to your Claude Code skills location:

```bash
cp -r mermaid-terminal ~/.claude/skills/
```

Or symlink it:

```bash
ln -s "$(pwd)/mermaid-terminal" ~/.claude/skills/mermaid-terminal
```

The skill will automatically install the `mermaid-ascii` npm package on first use if not already present.

## What It Does

When you ask Claude Code to explain something that involves:

- Process flows or workflows
- System architecture
- API call sequences
- Data pipelines
- State machines
- Decision trees

Claude can render a Mermaid diagram as ASCII art directly in your terminal output.

## Limitations

The ASCII renderer works best with simple diagrams:

- Maximum 8 nodes per diagram
- Maximum 10 edges
- No subgraphs
- Short labels (under 20 characters)

For complex systems, the skill guides Claude to split into multiple simple diagrams.

## Requirements

- Node.js and npm (for mermaid-ascii)
- Bash shell

## License

MIT
