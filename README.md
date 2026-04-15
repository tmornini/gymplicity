# Gymplicity

Trainer-first iOS gym tracking app. SwiftUI + SwiftData + Swift Charts. iOS 17+.

## Build & Test

```bash
build/simulate            # build for iOS Simulator
build/device TEAM_ID      # build and install on connected iPhone
build/distribute          # archive for distribution (Release)
build/test                # run tests on iOS Simulator
```

Tests are part of the build flow — code must build, function, and pass tests at each commit. Run `build/test` before pushing.

## Architecture

- [`CLAUDE.md`](CLAUDE.md) — project memory, conventions, verb semantics
- [`VISION.md`](VISION.md) — product vision and screen architecture
- [`SCHEMA.md`](SCHEMA.md) — full data model documentation

## Coding Standards — The Church of Code

This repo follows [**The Church of Code**](https://github.com/The-Church-of-Code/church-of-code) — a ranked hierarchy of commandments, articles of faith, abominations, and daily offices that bind software engineering work. Every change made in this repo is expected to conform to its strictures.

The scripture is distributed as a Claude Code plugin that bundles the `church-of-code` skill. When installed, the skill auto-activates whenever you brainstorm, plan, write, refactor, maintain, review, or commit code — loading the scripture into context so the work adheres to it.

### Installing the plugin (and its skill)

Inside Claude Code, run:

```
/plugin marketplace add The-Church-of-Code/church-of-code
/plugin install church-of-code@church-of-code-marketplace
```

The first command registers the marketplace. The second installs the `church-of-code` plugin, which includes the `church-of-code` skill. After installation, the skill is available via the `Skill` tool and is triggered automatically by its description when relevant to the work at hand.

To read the full scripture outside Claude Code, visit the repository:
<https://github.com/The-Church-of-Code/church-of-code>
