# Agent workflow best practices

Main rule of thumb: **Claude's performance is directly tied to how well you manage context.**

**Context is the scarce resource.** Performance degrades as it fills. Every decision below flows from this.

---

## 1. CLAUDE.md — the "always loaded" file

**It loads every session. Every line is a tax on every conversation.**

### The rule of thumb

**Start empty. Add a line only after Claude makes the same mistake twice.**
Don't pre-populate with "what a good dev should know" — let pain justify each entry. A CLAUDE.md that grows from observed failures will always beat one written up-front.

### What actually belongs here

Only things that are **always relevant** AND **not inferrable from the code**:

- Non-guessable commands (`bin/rspec`, `bin/dev`)
- Style rules that differ from language defaults
- Env quirks / required variables
- Non-obvious gotchas Claude keeps tripping on

### What doesn't — and where it goes instead

| Tempting to add                          | Better home                                                                              |
| ---------------------------------------- | ---------------------------------------------------------------------------------------- |
| Branch naming, PR template, commit style | **Skill** (`open-pr`, `setup-feature-branch`) — only loads when you're actually doing it |
| Migration / deployment recipes           | **Skill**                                                                                |
| "Run lint after every edit"              | **Hook** (deterministic, not advisory)                                                   |
| API docs, architecture tour              | Link out; don't inline                                                                   |
| File-by-file codebase description        | Delete — Claude reads code                                                               |
| "Write clean code", "add tests"          | Delete — platitudes                                                                      |

### Failure signals

- Claude ignores a rule → file is too long, rule got lost → **prune, don't emphasize**.
- Claude asks a question the file already answers → wording is ambiguous → **rewrite, don't append.**
- You keep repeating the same correction in chat → **that's the moment to add one line**.

### One-liners for the slide

- **Empty until proven otherwise.**
- **Pain or repeated mistake earns a line. Nothing else does.**
- **If it only applies sometimes → Skill. If it must be enforced → Hook. If it's always true and non-obvious → CLAUDE.md.**
- **A bloated CLAUDE.md is worse than no CLAUDE.md** — rules hide in the noise.

---

## 2. When to reach for what — the decision matrix

| Need                                                      | Use                                         |
| --------------------------------------------------------- | ------------------------------------------- |
| Applies **every session, globally**                       | **CLAUDE.md**                               |
| Domain knowledge / workflow loaded **only when relevant** | **Skill**                                   |
| Task that reads many files or needs **isolated context**  | **Subagent**                                |
| Action that **must happen deterministically, every time** | **Hook**                                    |
| Access to an **external system** (Jira, DB, Figma)        | **MCP server**                              |
| Repeatable CLI action with arguments                      | **Slash command / skill with `$ARGUMENTS`** |

ℹ Memorable frame: **CLAUDE.md = always. Skill = sometimes. Subagent = elsewhere. Hook = guaranteed.**

---

## 3. Skills — when to define one

- The workflow is **project- or domain-specific** (API conventions, migration recipe, translation flow).
- You'd otherwise paste the same instructions repeatedly.
- Set `disable-model-invocation: true` for side-effectful workflows you want to trigger manually.
- Keep `SKILL.md` short; Claude loads it on demand.

---

## 4. Subagents — when to define one

- Task pollutes main context (reads 50 files, explores a module).
- Needs a **different persona or tool scope** (e.g., security reviewer with read-only tools).
- Independent verification ("review what I just wrote") — fresh context = unbiased.
- Define in `.claude/agents/`, restrict `tools:`, pick `model:` intentionally.

---

## 5. Hooks — when to define one

- **Non-negotiable** actions: run linter after every edit, block writes to `/migrations`, reject secrets.
- Use when CLAUDE.md rules keep getting ignored — promote the rule to a hook.

---

## 6. Prompting: specific beats clever

**Before → After** pattern:

- "add tests for foo.py" → "write a test for foo.py covering logged-out edge case, no mocks"
- "add a calendar widget" → "follow `HotDogWidget.php` pattern, no new libraries"
- "fix the login bug" → "session-timeout login fails; check `src/auth/token_refresh`; write a failing test first"

Rich inputs: **`@file`**, paste screenshots, paste URLs, `cat log | claude`.

---

## 7. The core workflow: Explore → Plan → Code → Commit

1. **Plan Mode** to read & ask — no changes.
2. Produce a plan. `Ctrl+G` to edit it yourself.
3. Exit plan mode, implement, verify.
4. Commit with message + PR.

**Skip planning** if you can describe the diff in one sentence.

---

## 8. Verification is the highest-leverage habit

**Give Claude a way to check itself** — tests, screenshots, expected output, a lint command. Without it, *you* are the only feedback loop.

---

## 9. Context hygiene

- `/clear` between **unrelated tasks**.
- `/compact <focus>` to steer summarization.
- `Esc` to interrupt; `Esc Esc` or `/rewind` to roll back.
- After **2 failed corrections** → `/clear` and rewrite the prompt. Don't keep patching.
- Use **subagents for investigation** so the main session stays clean.
- `/btw` for throwaway questions that shouldn't enter history.

---

## 10. The 5 failure patterns (name-and-shame list)

1. **Kitchen-sink session** → `/clear` between topics.
2. **Correction spiral** → after 2 failures, reset with a better prompt.
3. **Over-specified CLAUDE.md** → prune or convert to a hook.
4. **Trust-then-verify gap** → no verification = don't ship.
5. **Infinite exploration** → scope it, or delegate to a subagent.

---

## Closing slide — memorable one-liners

- **Context is the budget.** Spend it on the current task only.
- **CLAUDE.md = pain justifies additions.**
- **If it must happen every time, it's a hook — not a note.**
- **Sometimes = skill. Elsewhere = subagent. Always = CLAUDE.md.**
- **No verification, no ship.**
- **After two corrections, clear.**
