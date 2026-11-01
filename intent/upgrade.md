# Intent: Make Progressive Intent the Default IDE Operating Model

## Outcome

Progressive Intent is the default operating model of this starter, built on the existing structure rather than beside it.

**Repository State + Next Intent = Next Repository State**

**Intent → Build → Observe → Learn → Refine → Continue or Stop**

The human owns the outcome, authoritative inputs, required outputs, true boundaries, evidence, observations of the running result, and the continue or stop decision. Human feedback may be informal ("keep this", "change that", "too complicated").

The AI owns reasoning, planning, architecture, implementation approach, sequencing, code structure, technical choices, and testing approach, unless genuinely constrained.

Apply minimum sufficient constraint: structure the boundary, not the reasoning.

## Outputs

- `intent/current-feature.md` uses a minimum-sufficient format: Outcome, Inputs, Outputs, Success / Evidence, and Constraints / Boundaries only when real. Empty sections are allowed.
- A delta format (Observation, Keep, Change, New Boundary, Evidence) that captures only what changed.
- The feature planner determines the smallest useful delta from repository state and intent, instead of breaking a feature into steps.
- One Progressive Intent skill: observation → next minimum intent delta.
- `pre-implement` validates sufficient intent, not a complete specification.
- A README operating-model section that explains Intent-Driven Engineering, Progressive Intent, and that every cycle ends in Continue or Stop.
- The starter installs from its marketplace with one command line and is usable in any project straight after.

## Decisions

- **Deltas are appended to the feature's intent file.** One file to read, and the original intent is never rewritten.
- **`pre-implement` is a runnable check.** Deterministic rule: the intent states an Outcome and a Success / Evidence. The previous section names (Business Outcome, Acceptance Criteria) still pass.
- **The four agents stay**, each with a one-line responsibility. None is removed, and no Progressive Intent agent is added.
- **The architecture page and image are redrawn.** `docs/architecture.html` shows the Progressive Intent loop, and the images in `docs/images/` are rendered from it.
- **The repo is an installable plugin and its own marketplace.** Skills and agents use the plugin layout, and `hooks/hooks.json` runs the pre-implement check before code edits in projects that have an intent file. Markdown is never blocked.
- **One `start` skill is added.** A plugin install does not copy files into a project, so something has to create the first intent file there.

## Success / Evidence

- `bash tests/pre-implement.test.sh` passes, and CI runs it.
- The blank intent fails the check; an intent with only Outcome and Success / Evidence passes; a previous-format intent passes.
- The README shows one example cycle: a first intent and the delta that follows an observation.
- `claude plugin validate .` passes.
- Every added file has a stated reason. If the reason cannot be given, the file is removed.

Not evidenced here: a new application, an existing application, and a refinement of a running result. This starter has no application to run, so those flows are proven in the first project that uses it.

## Constraints / Boundaries

- Do not create a parallel framework, an orchestration layer, more than one Progressive Intent skill, or hooks that dictate reasoning.
- Engineering discipline stays: architecture, testing, security, documentation, QA, review, and CI are applied when the problem and evidence justify them.
- The upgraded starter must be simpler to use than the previous one.

## Stop Condition

Stop when the starter supports small intent → build → observe → learn → refine → continue or stop without a second framework.
