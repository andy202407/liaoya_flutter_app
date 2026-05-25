---
inclusion: auto
---

# Context Efficiency Rules

- chat_page.dart is 2500+ lines. Always use grep_search or read_file with line ranges instead of reading the full file.
- Prefer targeted reads (start_line/end_line) over full file reads for any file over 200 lines.
- Never read node_modules, build/, .dart_tool/, pubspec.lock, or *.g.dart files.
- When modifying chat_page.dart, read only the specific method being changed (use grep to find it first).
