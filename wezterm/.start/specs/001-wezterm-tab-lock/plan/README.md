---
title: "WezTerm Tab Lock"
status: draft
version: "1.0"
---

# Implementation Plan

## Validation Checklist

### CRITICAL GATES (Must Pass)

- [x] All `[NEEDS CLARIFICATION: ...]` markers have been addressed
- [x] All specification file paths are correct and exist
- [x] Each phase follows TDD: Prime → Test → Implement → Validate
- [x] Every task has verifiable success criteria
- [x] A developer could follow this plan independently

### QUALITY CHECKS (Should Pass)

- [x] Context priming section is complete
- [x] All implementation phases are defined with linked phase files
- [x] Dependencies between phases are clear (no circular dependencies)
- [x] Parallel work is properly tagged with `[parallel: true]`
- [x] Activity hints provided for specialist selection `[activity: type]`
- [x] Every phase references relevant SDD sections
- [x] Every test references PRD acceptance criteria
- [x] Integration & E2E tests defined in final phase
- [x] Project commands match actual project setup

---

## Context Priming

*GATE: Read all files in this section before starting any implementation.*

**Specification**:

- `.start/specs/001-wezterm-tab-lock/requirements.md` - Product Requirements (4 features, 10 acceptance criteria)
- `.start/specs/001-wezterm-tab-lock/solution.md` - Solution Design (5 ADRs, full implementation examples)

**Key Design Decisions**:

- **ADR-1**: State storage — `wezterm.GLOBAL.locked_tabs` in-memory table (survives config reloads, resets on exit)
- **ADR-2**: Close behavior — Silent block + toast notification (no confirmation dialog)
- **ADR-3**: Visual indicator — Lock icon via `wezterm.nerdfonts.fa_lock` in tab title (string return)
- **ADR-4**: Toggle keybinding — CMD+SHIFT+L (follows existing CMD+SHIFT pattern)
- **ADR-5**: Tab title rendering — String return from `format-tab-title` (preserves Catppuccin colors automatically)

**Implementation Context**:

```bash
# WezTerm has no build/test/lint tooling
# All verification is manual:
Reload config:  CMD+CTRL+, (or restart WezTerm)
Test:           Manual — lock tab, try CMD+W, verify toast + icon
Lint:           N/A (WezTerm Lua requires WezTerm runtime, cannot syntax-check externally)
```

---

## Implementation Phases

Each phase is defined in a separate file. Tasks follow red-green-refactor: **Prime** (understand context), **Test** (red), **Implement** (green), **Validate** (refactor + verify).

> **Note**: This is a single-phase feature. All components are closely coupled within one file (`wezterm.lua`). No multi-phase decomposition needed.

- [x] [Phase 1: Tab Lock Feature](phase-1.md)

---

## Plan Verification

Before this plan is ready for implementation, verify:

| Criterion | Status |
|-----------|--------|
| A developer can follow this plan without additional clarification | ✅ |
| Every task produces a verifiable deliverable | ✅ |
| All PRD acceptance criteria map to specific tasks | ✅ |
| All SDD components have implementation tasks | ✅ |
| Dependencies are explicit with no circular references | ✅ |
| Parallel opportunities are marked with `[parallel: true]` | ✅ |
| Each task has specification references `[ref: ...]` | ✅ |
| Project commands in Context Priming are accurate | ✅ |
| All phase files exist and are linked from this manifest as `[Phase N: Title](phase-N.md)` | ✅ |
