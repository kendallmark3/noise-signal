# Install the Intent-Driven Engineering starter plugin

The starter is a Claude Code plugin. Install it once and it is available in every repository you open with Claude Code.

## Before you start

You need:

- [Claude Code](https://claude.com/claude-code), with the `claude` command available in your terminal
- `git`, which Claude Code uses to fetch the plugin
- `bash`, which the plugin's check runs in (on Windows, use Git Bash or WSL)

## Install

Run these two commands in a terminal. It does not matter which folder you are in.

```bash
claude plugin marketplace add kendallmark3/intent-drive-starter
claude plugin install intent-drive-starter@intent-drive-starter
```

The first command tells Claude Code where the plugin lives. The second installs it.

Then start a new Claude Code session. Plugins load when a session starts, so a session that was already open will not see it.

To confirm it worked:

```bash
claude plugin list
```

You should see `intent-drive-starter@intent-drive-starter` with the status `enabled`.

## First use

Open Claude Code in any repository and run:

```text
/intent-drive-starter:start <the outcome you want>
```

For example:

```text
/intent-drive-starter:start operators can see the status of last night's jobs on one page
```

Claude creates `intent/current-feature.md` in your repository, writes down the outcome and how success will be judged, and builds the smallest thing you can look at. If you did not say how success will be judged, it asks you.

Then look at the result and say what you think in plain words: "keep the layout", "this is too busy", "don't change the backend". That feedback becomes the next small change. Each round ends with one question: continue or stop.

## What you get

### Skills

Skills are instructions Claude follows for a particular job. You can run one by name, and Claude also picks them up on its own when the situation fits.

| Skill | Command | What it does |
| --- | --- | --- |
| Start | `/intent-drive-starter:start` | Sets up the intent file in your repository, records the outcome and the evidence of success, and builds the first thing you can observe. |
| Feature planner | `/intent-drive-starter:feature-planner` | Reads the repository and the current intent, and works out the smallest useful change to make next. |
| Progressive intent | `/intent-drive-starter:progressive-intent` | Turns your feedback on a running result into a short "delta" appended to the intent file: what you observed, what to keep, what to change. |

### Agents

Agents are roles Claude can hand part of the work to. A normal session can run the whole loop without them; they are there when you want the work split up.

| Agent | What it does |
| --- | --- |
| `intent-drive-starter:planner` | Works out the smallest useful change from the repository and the intent. |
| `intent-drive-starter:developer` | Builds that change. |
| `intent-drive-starter:qa` | Runs the tests and checks the result against the evidence the intent asked for. |
| `intent-drive-starter:reviewer` | Reviews the change against the intent and its deltas, not just the diff. |

### One safety check

The plugin adds one automatic check. Before Claude edits a code file, it confirms that `intent/current-feature.md` states two things:

- an **Outcome**
- a **Success / Evidence**

If either is missing, the edit is blocked and Claude is told which one to fill in.

The check stays out of your way in three cases:

- Repositories with no `intent/current-feature.md` are never checked. Nothing changes until you run `start` there.
- Markdown files are never blocked, so the intent itself can always be written.
- It does not ask for requirements, architecture, or a full specification. Two filled-in sections are enough.

### Templates

The plugin carries the two templates its skills use:

- **Feature intent:** Outcome, Inputs, Outputs, Success / Evidence, Constraints / Boundaries. Only the first and fourth are required.
- **Intent delta:** Observation, Keep, Change, New Boundary, Evidence. Use only the sections you need.

## What it adds to your repository

One file: `intent/current-feature.md`, created the first time you run `start`. Deltas are appended to that same file. The plugin itself lives in your Claude Code settings, not in your repository.

## Update or remove

```bash
claude plugin update intent-drive-starter@intent-drive-starter
claude plugin uninstall intent-drive-starter@intent-drive-starter
```

## Learn more

- [README](README.md) for the operating model and the architecture diagram
- [learnteachmaster.org](https://learnteachmaster.org)
- [intent-driven-engineering.com](https://intent-driven-engineering.com)
