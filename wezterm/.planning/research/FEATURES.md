# Feature Research

**Domain:** Terminal Session Management
**Researched:** 2026-03-14
**Confidence:** MEDIUM (based on training data; web search tools unavailable)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Named session creation** | Core concept - "create a session called 'work'" | LOW | `tmux new -s name`, `zellij -s name` - users expect name-based organization |
| **Session listing** | "Show me what sessions exist" is fundamental discovery | LOW | `tmux ls`, `zellij ls` - must show session names and basic state |
| **Attach to session by name** | "Connect to my 'work' session" - core workflow | LOW | `tmux attach -t name`, `zellij attach name` - prerequisite for multi-session use |
| **Detach from session** | Leave session running while closing terminal window | LOW | Ctrl+B D (tmux), keyboard shortcut - users expect sessions to persist after disconnect |
| **Session persistence across disconnects** | Sessions survive terminal close/crashes | MEDIUM | Requires daemon process - this is THE killer feature of multiplexers |
| **Kill/delete session** | Remove unwanted sessions to clean up | LOW | `tmux kill-session -t name` - basic lifecycle management |
| **Multiple tabs/windows per session** | Sessions contain multiple workspaces | MEDIUM | tmux windows, zellij tabs - expected organization primitive |
| **Pane splitting (vertical/horizontal)** | Divide screen into multiple panes | MEDIUM | Standard multiplexer feature - users expect tiling |
| **Session state survives SSH disconnect** | Primary use case for remote work | N/A | Out of scope for v1 per PROJECT.md, but users coming from tmux expect this |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Git-versioned session definitions** | Sessions as code - commit/share/sync workspace configs | LOW | Store JSON in `~/.config/wezterm/sessions/` - nobody else does this well |
| **Layout auto-save on changes** | Sessions always reflect current state, no manual save | MEDIUM | Watch for pane/tab changes and persist automatically - reduces friction |
| **Command restoration** | Re-launch `nvim`, `claude`, `npm dev` on session restore | HIGH | Killer feature - most tools don't preserve running commands, only working directories |
| **Fuzzy session picker in-terminal** | Quick switching with keyboard-driven UI | MEDIUM | Like Telescope for sessions - faster than `tmux choose-tree` |
| **Session picker on launch** | Choose what to restore instead of auto-restore everything | LOW | Better UX than tmux's "restore last" or zellij's "restore all" |
| **Zero external dependencies** | Works out of WezTerm install, no tmux/zellij binary needed | LOW | Competitive advantage vs multiplexers - leverages native WezTerm mux |
| **Native terminal emulator integration** | No escape key conflicts, full color/font support | LOW | tmux has key binding conflicts and color quirks - WezTerm-native avoids this |
| **Session templates** | Pre-defined layouts for common workflows (e.g., "fullstack" = 3 panes) | MEDIUM | Users can create reusable session configs - more ergonomic than shell scripts |
| **Session inheritance** | Create new session based on existing one | MEDIUM | `wez-session new --from work` - useful for variations on a theme |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Auto-restore all sessions on launch** | "I want everything back instantly" | Overwhelming - 10+ sessions restored means slow startup and cognitive overload | Session picker - user chooses what to restore |
| **Automatic command history replay** | "Restore my shell history in each pane" | Dangerous - re-running commands can have side effects (deletes, API calls, etc.) | Restore working directory only, let user review/re-run |
| **Remote session sync across machines** | "Access my work session from laptop and desktop" | Complex state synchronization, race conditions, network dependencies | Git-commit session definitions, restore locally on each machine |
| **GUI session manager app** | "Click-to-switch sessions in a window" | Adds dependency, maintenance burden, violates terminal-first philosophy | CLI + in-terminal fuzzy picker - keyboard-driven is faster |
| **Full process state persistence** | "Save everything including process memory" | Impossible without CRIU-like checkpoint/restore - brittle and platform-specific | Save enough metadata to re-launch processes cleanly |
| **Session sharing/collaboration** | "Let others attach to my session" | Security nightmare, complex permissions, out of scope | Use tmate or built-in SSH if needed - v1 is local-only |
| **Unlimited undo/redo for layout changes** | "Undo that split I just made" | Complex state management, memory overhead, rarely used in practice | Make splits easy to close/recreate instead |

## Feature Dependencies

```
[Named Sessions]
    └──requires──> [Session Persistence Daemon]
                       └──requires──> [WezTerm Mux Server]

[Session Restore]
    ├──requires──> [Layout Persistence]
    │                  └──requires──> [JSON Serialization]
    ├──requires──> [Working Directory Capture]
    └──optional──> [Command Restoration]

[Fuzzy Session Picker]
    ├──requires──> [Session Listing]
    └──enhances──> [Quick Session Switching]

[Session Templates]
    ├──requires──> [Layout Persistence Format]
    └──enhances──> [Session Creation Workflow]

[Auto-save on Changes]
    ├──requires──> [Layout Change Detection]
    └──conflicts──> [Manual Save Control] (if user wants explicit saves)

[Command Restoration]
    ├──requires──> [Process Command Capture]
    └──requires──> [Working Directory Capture]
```

### Dependency Notes

- **Session Persistence requires Daemon:** Without a running mux server, sessions can't survive terminal closure - this is foundational
- **Session Restore requires Layout Persistence:** Can't restore what wasn't saved - JSON format is prerequisite
- **Command Restoration enhances Session Restore:** Working directories alone are useful, but command restoration is the killer feature
- **Auto-save conflicts with Manual Save:** If auto-saving is too aggressive, users lose control - need configurable behavior
- **Fuzzy Picker enhances Switching:** Session listing is table stakes, but fuzzy search makes switching ergonomic

## MVP Definition

### Launch With (v1)

Minimum viable product - what's needed to validate the concept.

- [ ] **Named session creation** — Can't have sessions without names
- [ ] **Session listing** — Discovery is essential
- [ ] **Attach to session by name** — Core workflow
- [ ] **Session persistence daemon (launchd)** — The whole point is surviving terminal close
- [ ] **Layout save/restore (tabs + panes + directories)** — Basic persistence
- [ ] **Session kill/delete** — Lifecycle management
- [ ] **Fuzzy session picker** — Differentiation from basic tmux ls + attach
- [ ] **CLI wrapper (`wez-session`)** — User-facing interface
- [ ] **Session picker on launch** — Better UX than auto-restore

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **Command restoration** — Add when layout persistence is proven stable
- [ ] **Session templates** — Add when users request common patterns
- [ ] **Session inheritance** — Add when template usage shows demand
- [ ] **Auto-save on layout changes** — Add when users complain about manual saves
- [ ] **Session metadata (description, tags)** — Add when users have many sessions and need organization

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Remote session support (SSH domains)** — Complex, defer until local sessions are proven
- [ ] **Multi-machine sync** — Defer until git-versioning workflow is validated
- [ ] **Session snapshots/versioning** — Defer until users request time-travel debugging
- [ ] **Plugin system for custom serializers** — Defer until power users request extensibility
- [ ] **Session analytics (time spent per session)** — Defer until basic features are complete

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Named session create/list/attach | HIGH | LOW | P1 |
| Session persistence daemon | HIGH | MEDIUM | P1 |
| Layout save/restore | HIGH | MEDIUM | P1 |
| Session kill/delete | HIGH | LOW | P1 |
| Fuzzy session picker | HIGH | MEDIUM | P1 |
| CLI wrapper interface | HIGH | LOW | P1 |
| Session picker on launch | MEDIUM | LOW | P1 |
| Command restoration | HIGH | HIGH | P2 |
| Session templates | MEDIUM | MEDIUM | P2 |
| Auto-save on changes | MEDIUM | MEDIUM | P2 |
| Session inheritance | LOW | LOW | P2 |
| Session metadata (tags/descriptions) | LOW | LOW | P2 |
| Remote session support | HIGH | HIGH | P3 |
| Multi-machine sync | MEDIUM | HIGH | P3 |
| Session snapshots | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | tmux | zellij | kitty sessions | WezTerm (native) |
|---------|------|--------|----------------|-------------------|
| **Named sessions** | ✓ `new -s name` | ✓ `-s name` | ✗ No session concept | ✓ Via workspaces + wrapper |
| **Session listing** | ✓ `ls` | ✓ `ls` | N/A | ✓ Via CLI wrapper |
| **Attach/detach** | ✓ Manual attach | ✓ Manual attach | N/A | ✓ Via CLI wrapper |
| **Persistence** | ✓ Server daemon | ✓ Server daemon | ✗ Process-based | ✓ Via mux server |
| **Layout persistence** | ✗ Requires tmux-resurrect plugin | ✗ Manual save | ✓ Built-in (limited) | ✓ JSON serialization (planned) |
| **Command restoration** | ✗ (tmux-resurrect partial) | ✗ | ✗ | ✓ Planned differentiator |
| **Fuzzy picker** | ✗ (choose-tree is basic) | ✗ (list is text-based) | N/A | ✓ Planned differentiator |
| **Git-versioned configs** | ✗ (config yes, sessions no) | ✗ (config yes, sessions no) | ✓ (layouts) | ✓ Planned differentiator |
| **Zero dependencies** | ✗ Requires tmux binary | ✗ Requires zellij binary | ✓ Built-in | ✓ Native WezTerm |
| **Remote sessions (SSH)** | ✓ Core use case | ✓ Supported | ✗ | ✗ v1 out of scope |
| **Pane/window management** | ✓ Extensive | ✓ Modern UI | ✓ Limited | ✓ Via WezTerm built-ins |
| **Session templates** | ✗ (shell scripts common) | ✗ (manual layouts) | ✓ Launch scripts | ✓ Planned feature |

### Key Insights

**tmux strengths:**
- Battle-tested session persistence
- Ubiquitous on servers
- Extensive plugin ecosystem (resurrect, continuum)

**tmux weaknesses:**
- Layout persistence requires plugins (tmux-resurrect) and is brittle
- No command restoration without hacky process inspection
- Key binding conflicts with other tools
- Sessions not version-controllable

**zellij strengths:**
- Modern UI with better discoverability
- Built-in layouts are more intuitive
- Better default keybindings

**zellij weaknesses:**
- No built-in session persistence across reboots (sessions are ephemeral unless manually saved)
- Still requires external binary
- Younger ecosystem

**kitty strengths:**
- Native terminal integration
- Session layouts can be saved

**kitty weaknesses:**
- No true session persistence (tied to process lifecycle)
- No detach/re-attach workflow
- Limited to kitty terminal

**WezTerm native opportunity:**
- Combine tmux's persistence with kitty's native integration
- Git-versionable session definitions (neither tmux nor zellij do this well)
- Command restoration as killer feature
- Fuzzy picker for better UX
- Zero external dependencies

## Session Workflow Patterns (Observed)

### Pattern 1: Project-Based Sessions
**User behavior:** One session per codebase/project
- Session name = project name
- Panes = editor, terminal, logs, tests
- Working directory = project root
- Commands = `nvim`, `npm run dev`, `tail -f logs`

**Implication for WezTerm:** Session templates for common project layouts

### Pattern 2: Context-Based Sessions
**User behavior:** One session per role/context
- Session names = "personal", "work", "client-X"
- Multiple projects per session as tabs
- Switch sessions to change mental context

**Implication for WezTerm:** Session switching needs to be fast (fuzzy picker)

### Pattern 3: Persistent "Home" Session
**User behavior:** Always-on session for quick tasks
- Session name = "main" or "default"
- Never killed, always attached
- General-purpose workspace

**Implication for WezTerm:** Session picker should show "last used" or "default" session

### Pattern 4: Ephemeral Experiment Sessions
**User behavior:** Quick throwaway sessions for testing
- Short-lived, killed after task
- No need to persist layout

**Implication for WezTerm:** Don't force saving everything - allow ephemeral sessions

## Critical Feature Interactions

### Daemon + Session Persistence = Core Value
- Without daemon: sessions die when WezTerm closes (useless)
- Without session concept: just a persistent terminal (not organized)
- Together: tmux/zellij parity achieved

### Layout Persistence + Command Restoration = Killer Feature
- Layout alone: useful but not differentiated (tmux-resurrect does this)
- Commands alone: brittle without layout context
- Together: unique selling point - full workflow restoration

### Fuzzy Picker + Git-Versioned Sessions = Workflow Win
- Fuzzy picker alone: nice UX improvement
- Git-versioned alone: interesting but requires manual management
- Together: fast switching between committed workspace configs

### Auto-Save + Manual Snapshots = Flexibility
- Auto-save alone: might surprise users or create unwanted states
- Manual save alone: users forget and lose work
- Together: auto-save working state, manual snapshots for important configs

## Sources

**Note:** Web search tools were unavailable during research (WebSearch API errors, Brave Search requires API key). This analysis is based on:

- Training data knowledge of tmux, zellij, screen, kitty (knowledge cutoff: January 2025)
- Common usage patterns from terminal multiplexer communities
- WezTerm documentation and capabilities (from project context)

**Confidence level: MEDIUM**
- Feature lists for tmux/zellij are well-established and stable (HIGH confidence)
- Specific version features for 2026 not verified (MEDIUM confidence)
- User workflow patterns based on community observation (MEDIUM confidence)
- WezTerm capabilities verified from project context (HIGH confidence)

**Recommendation:** Validate feature priorities with:
- tmux documentation: https://github.com/tmux/tmux/wiki
- zellij documentation: https://zellij.dev/documentation/
- WezTerm documentation: https://wezfurlong.org/wezterm/
- tmux-resurrect plugin: https://github.com/tmux-plugins/tmux-resurrect (to understand layout persistence patterns)

---
*Feature research for: WezTerm Session Manager*
*Researched: 2026-03-14*
*Confidence: MEDIUM (web search unavailable, training data based)*
