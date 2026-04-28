---
name: tmux-mosaic-fast-loop
description: Minimize tmux-mosaic iteration time with filtered Bats runs and one final CI gate
user-invocable: true
version: 1.0.0
---

# /tmux-mosaic-fast-loop

Use this skill for `tmux-mosaic` development when the goal is to keep the inner
loop fast without weakening the final verification bar.

## Repo assumptions

- The repo uses `justfile`, `flake.nix`, and `.envrc`.
- Prefer `direnv exec /home/barrett/dev/tmux-mosaic just <recipe>` for one-shot
  commands in the default dev shell.
- Treat `nix develop /home/barrett/dev/tmux-mosaic#ci --command just ci` as the
  final pre-PR gate, not the default inner-loop command.
- The repo provides fast helpers:
  - `just test-one '<bats filter>'`
  - `just test-file <integration-file>`
  - `just test-new-pane`

## Fast inner loop

1. Start with the narrowest targeted tests that cover the changed area.
2. Use `BATS_FILTER` instead of rerunning the entire integration suite after
   every edit.
3. Run `just format` and `just lint` after the code stabilizes or when touching
   files those checks actually cover.
4. Run one full `nix develop /home/barrett/dev/tmux-mosaic#ci --command just ci`
   when the branch is ready for review.

## Recommended targeted commands

- Broad `new-pane` iteration:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-new-pane`
- `grid` work:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-one '^grid:|new-pane acceptance: grid|new-pane fast paths: grid'`
- `monocle` work:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-one '^monocle:|new-pane acceptance: monocle'`
- min-size fallback work:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-one 'falls back|raw split reports no space'`

## Flake handling

- If a full run fails in an area outside the changed surface, rerun that exact
  test with `BATS_FILTER` before any new full-suite run.
- Known noisy areas include:
  - `tests/integration/option_hook.bats` drag-resize relayout-count checks
  - `tests/integration/master_stack.bats` top-orientation drag-resize mfact sync
- A passing isolated rerun of an unrelated noisy test is a signal to keep
  developing, not a signal to immediately restart the whole suite.

## Worktree and docs hygiene

- If local `main` cannot fast-forward cleanly because of local dirt or untracked
  files, create a clean worktree from `origin/main` under
  `/tmp/tmux-mosaic/<task-slug>/`.
- Keep README and other docs edits until the end of a multi-issue batch so the
  final docs pass happens once.
