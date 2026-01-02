# mermaid-terminal

A Claude Code skill that renders Mermaid diagrams as ASCII art directly in the terminal.

## Overview

This skill enables Claude Code to visualize diagrams when explaining processes, workflows, architectures, and sequences. Instead of describing relationships in text, Claude can render actual diagrams that display in your terminal.

## Credits

This skill is powered by [mermaid-ascii](https://github.com/AlexanderGrooff/mermaid-ascii) by Alexander Grooff, a tool that converts Mermaid diagram syntax into ASCII art.

## Installation

Copy the `mermaid-terminal` directory to your Claude Code skills location:

**Linux/macOS:**
```bash
cp -r mermaid-terminal ~/.claude/skills/
```

Or symlink it:

```bash
ln -s "$(pwd)/mermaid-terminal" ~/.claude/skills/mermaid-terminal
```

**Windows (PowerShell):**
```powershell
Copy-Item -Recurse mermaid-terminal "$env:USERPROFILE\.claude\skills\"
```

The skill will automatically install the `mermaid-ascii` binary on first use if not already present.

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

**Linux/macOS:**
- Bash shell
- curl (for downloading mermaid-ascii if not installed)

**Windows:**
- PowerShell 5.1+ (included in Windows 10/11)

## License

MIT
