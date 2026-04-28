# tmux-mosaic agent notes

## Workflow

- Prefer `direnv exec /home/barrett/dev/tmux-mosaic just <recipe>`
- Canonical verification surface:
  - `just format`
  - `just lint`
  - `just test`
  - `just ci`
- Fast-path helper recipes:
  - `just test-one '<bats filter>'`
  - `just test-file <integration-file>`
  - `just test-new-pane`

## Fast inner-loop verification

- Do not use `just ci` or the full `just test` suite as the default inner-loop command for small iterations.
- For development work, prefer the targeted helper recipes or direct `BATS_FILTER` runs, then save one full `nix develop /home/barrett/dev/tmux-mosaic#ci --command just ci` run for the final pre-PR gate.
- Run `just format` and `just lint` after the code stabilizes or when touching files those checks actually cover; do not pay that cost after every tiny test-only or docs-only edit.
- If a full run fails in an area you did not touch, rerun that exact test with `BATS_FILTER` before rerunning the whole suite.
- Known noisy areas:
  - `tests/integration/option_hook.bats` drag-resize relayout-count checks
  - `tests/integration/master_stack.bats` top-orientation drag-resize mfact sync
- A passing isolated rerun of an unrelated noisy test is a reason to continue iterating, not a reason to immediately restart the full suite.
- Keep README and other docs edits until the end of a multi-issue implementation batch so they do not force extra verification loops.
- If syncing local `main` is blocked by local dirt or untracked files, create a clean worktree from `origin/main` under `/tmp/tmux-mosaic/<task-slug>/` instead of spending time repairing the current tree first.

### Fast verification map for explicit `new-pane` work

- Broad `new-pane` iteration:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-new-pane`
- `grid` policy work:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-one '^grid:|new-pane acceptance: grid|new-pane fast paths: grid'`
- `monocle` policy work:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-one '^monocle:|new-pane acceptance: monocle'`
- min-size fallback work:
  - `direnv exec /home/barrett/dev/tmux-mosaic just test-one 'falls back|raw split reports no space'`
- Only after the targeted checks pass, widen to the canonical gate:
  - `nix develop /home/barrett/dev/tmux-mosaic#ci --command just ci`

## Managed `new-pane` residual visual-glitch map

This section is for issue #100 and future work on explicit managed `new-pane`.

Definitions:

- `n` = current pane count before `new-pane`
- `m` = current `@mosaic-nmaster`
- `s = n - m` when `n > m`
- “primitive best effort” means choosing the best single tmux split target, axis, side, and initial size before the final relayout
- The append-order invariant from the README is assumed to stay in force

### Categories

- `exact local split`: one optimal split can already birth the new pane in the right local region
- `local equalization`: the right branch can be chosen immediately, but siblings in that row, column, or stack still must resize afterward
- `local role shift`: the new pane can be born in the right broad area, but at least one existing pane must change role inside that subtree
- `global reshape`: the final new-pane region is not the refinement of any one current pane
- `mirrored order conflict`: correct birth side and append-to-end order disagree in one split
- `zoom/focus snap`: no real spatial-placement problem remains; the only visible effect is zoom or focus assertion
- `min-size failure`: the intended target leaf is too small to split in the needed axis

### `master-stack`

- If `n < m`:
  - `n = 1`: `exact local split`
  - `n >= 2`: `local equalization`
- If `n = m = 1`:
  - orientation `left` or `top`: `exact local split`
  - orientation `right` or `bottom`: `mirrored order conflict`
- If `n = m > 1`: `global reshape`
  - this is the all-masters -> first-stack transition
- If `n > m`:
  - `s = 1`: `exact local split`
  - `s >= 2`: `local equalization`

### `centered-master`

- If `n < m`:
  - `n = 1`: `exact local split`
  - `n >= 2`: `local equalization`
- If `n = m = 1`: `exact local split`
- If `n = m > 1`: `global reshape`
  - this is the all-masters-column -> master-plus-stack transition
- If `n > m`:
  - `s = 1`: `local role shift`
    - the left stack appears for the first time and the master block recenters
  - `s = 2`: `exact local split`
  - `s >= 4` and `s` is even: `local equalization`
  - `s >= 3` and `s` is odd: `local role shift`
    - `left_n` increases by 1 and the master base shifts

### `three-column`

- If `n < m`:
  - `n = 1`: `exact local split`
  - `n >= 2`: `local equalization`
- If `n = m = 1`: `exact local split`
- If `n = m > 1`: `global reshape`
  - this is the all-masters-column -> master-plus-stack transition
- If `n > m`:
  - `s = 1`: `local role shift`
    - the middle column appears for the first time
  - `s >= 2` and `s` is even: `local role shift`
    - `middle_n` increases by 1 and one pane crosses from the right column into the middle column
  - `s = 3`: `exact local split`
  - `s >= 5` and `s` is odd: `local equalization`

### `even-horizontal`

- `n = 1`: `exact local split`
- `n >= 2`: `local equalization`
  - every append re-equalizes the full row

### `even-vertical`

- `n = 1`: `exact local split`
- `n >= 2`: `local equalization`
  - every append re-equalizes the full column

### `grid`

- `n = 1`: `exact local split`
- `n = 2`: `local role shift`
  - the old bottom full-width pane must move into the new top row
- If current `n` is `k^2` or `k(k + 1)` for any integer `k >= 2`: `global reshape`
  - examples: `4->5`, `6->7`, `9->10`, `12->13`, `16->17`, `20->21`
- All other `n`: `exact local split`

### `dwindle`

- If the current tail leaf is large enough to split: `exact local split`
- If the current tail leaf is too small in the required axis: `min-size failure`

There is no unavoidable role shift or global reshape in the algorithm itself.

### `spiral`

- If the next recursive tail insertion is a `leaf-node` step: `exact local split`
- If the next recursive tail insertion is a `node-leaf` step whose recursive subtree size is `1`: `exact local split`
  - the first obvious example is `3->4`
- If the next recursive tail insertion is a `node-leaf` step whose recursive subtree size is greater than `1`: `local role shift`
  - the first obvious example is `4->5`
- If the current tail leaf is too small in the required axis: `min-size failure`

This layout is not globally hard like `grid`, but it does have exact recursive phases where the old tail must be pushed inward.

### `monocle`

- If `window_zoomed_flag = 1`: no meaningful spatial glitch remains
- If `window_zoomed_flag = 0`: `zoom/focus snap`

This is a zoom assertion problem, not a branch-placement problem.

### Cross-cutting modifiers

- Non-default `@mosaic-mfact` increases the visibility of otherwise-local corrections in:
  - `master-stack`
  - `centered-master`
  - `three-column`
  - `spiral`
  - `dwindle`
- Small windows and deep recursion increase the chance of `min-size failure`
- The clean mirrored append-order conflict found so far is:
  - `master-stack`
  - `m = 1`
  - `n = 1`
  - orientation `right` or `bottom`

## External plugin research for explicit `new-pane`

This section compares tmux-mosaic's layouts to other tmux plugins and notes how
those plugins handle creation-time structural churn.

Surveyed repos:

- `emretuna/tmux-layouts`
- `gufranco/tmux-tiling-revamped`
- `saysjonathan/dwm.tmux`
- `whwright/awesomewm.tmux`
- `daneofmanythings/tmux-tiler`
- `jhornsberger/tmux-relative-layout`
- `2KAbhishek/tmux-tilit`

### Common patterns across other plugins

- Layout-aware `new-pane` is rare.
- The most common strategy is:
  - let tmux do a raw `split-window`
  - use hooks like `after-split-window`
  - re-apply the entire layout with `select-layout` or a custom layout string
- Plugins are generally willing to accept:
  - full reprojection after split
  - `swap-pane` / `move-pane` churn after split
  - hiding churn behind `resize-pane -Z` in monocle-like modes
- The strongest surveyed precedent for birth-first behavior is
  `emretuna/tmux-layouts`, especially for `vstack`, `hstack`, and `spiral`.
- The strongest surveyed precedent for full reprojection is
  `gufranco/tmux-tiling-revamped`.

### `master-stack`

Closest external analogs:

- `emretuna/tmux-layouts`
  - Files:
    - `scripts/new_pane.sh`
    - `scripts/apply_layout.sh`
    - `scripts/layout_engine.sh`
  - Analog: `vstack`
  - Behavior:
    - `new_pane.sh` chooses `split-window -h` for `vstack`
    - `apply_layout.sh` runs from `after-split-window`
    - `layout_engine.sh` then applies `select-layout main-vertical` and resizes the first pane
  - Takeaway:
    - This is a direct precedent for “split in the right first direction for a simple master/stack layout, then accept a final relayout/resize pass”

- `gufranco/tmux-tiling-revamped`
  - Files:
    - `tmux-tiling-revamped.tmux`
    - `src/tiling.sh`
    - `src/lib/layouts/main-vertical.sh`
    - `src/lib/layouts/main-horizontal.sh`
  - Analogs:
    - `main-vertical`
    - `main-horizontal`
  - Behavior:
    - No layout-specific `new-pane` command
    - `after-split-window` hook re-applies the current layout
    - `main-vertical.sh` and `main-horizontal.sh` call built-in `select-layout` and then resize the master pane
  - Takeaway:
    - This plugin accepts whatever raw split happened and fixes it afterward
    - It is not trying to birth the pane into the semantic stack tail

- `saysjonathan/dwm.tmux`
  - Files:
    - `bin/dwm.tmux`
    - `lib/dwm.tmux`
    - `README.md`
  - Analog: left master + right stack
  - Behavior:
    - `newpane()` does `split-window -t :.0`
    - then `swap-pane -s :.0 -t :.1`
    - then `select-pane -t :.0`
    - then re-applies `select-layout main-vertical` and resizes master width
  - Takeaway:
    - This is explicit split -> swap -> relayout churn
    - It preserves a “master is pane 0” invariant and accepts structural motion to do it

- `whwright/awesomewm.tmux`
  - File:
    - `awesomewm.tmux`
  - Analog: left master + right stack
  - Behavior:
    - Bound key does `split-window -t :.0`
    - then `swap-pane -s :.0 -t :.1`
    - then `select-layout main-vertical`
    - then resizes the master pane
  - Takeaway:
    - Same broad pattern as `dwm.tmux`
    - Birth correctness is not prioritized over post-split rearrangement

- `daneofmanythings/tmux-tiler`
  - Files:
    - `scripts/pane_open.sh`
    - `scripts/apply_layout.sh`
    - `README.md`
  - Analog: right main pane with a left stack
  - Behavior:
    - If only one pane exists, it uses `split-window -h`
    - If more than one pane exists, it selects `bottom-left` and splits there
    - `apply_layout.sh` then rotates on the second pane transition and equalizes the left stack afterward
  - Takeaway:
    - This is a useful precedent for targeting the existing stack branch instead of splitting the master once the stack exists
    - It still accepts post-birth reorder or rebalance work on the 1->2 transition

Overall conclusion for `master-stack`:

- Other plugins either:
  - split in the right broad direction and then resize, or
  - split generically and then reorder/reproject
- There is external precedent for birth-first handling of the simple master/stack case
- There is also strong precedent for accepting swap or relayout churn when preserving other invariants

### `centered-master`

Closest external analogs:

- `gufranco/tmux-tiling-revamped`
  - File:
    - `src/lib/layouts/main-center.sh`
  - Analog: centered master with balanced side columns
  - Behavior:
    - Builds a full custom tmux layout string from the entire pane list
    - Computes balanced left and right column counts from pane order
    - Applies the layout with `select-layout "${checksum},${layout_body}"`
    - No layout-aware `new-pane` fast path exists
    - New panes rely on generic split plus `after-split-window` reprojection
  - Takeaway:
    - This is the strongest external precedent for a centered-master-style layout
    - It does not attempt semantic birth placement
    - It accepts full-window reprojection after pane creation

- `jhornsberger/tmux-relative-layout`
  - File:
    - `layout.tmux`
  - Nearest analog:
    - `main_horizontal_tiled_layout`
    - `main_vertical_tiled_layout`
  - Behavior:
    - Starts from built-in `main-horizontal` or `main-vertical`
    - Then runs `move-pane` loops to interleave panes into alternating rows or columns
    - Then runs `resize-pane` loops to force the secondary pane band sizes
  - Takeaway:
    - This is not centered-master exactly
    - But it is useful precedent for complex multi-band layouts that accept explicit `move-pane` churn after birth

Overall conclusion for `centered-master`:

- The best surveyed analog simply recomputes and reapplies the whole layout after every split
- No surveyed plugin tries to solve centered-master with a layout-aware `new-pane` birth path

### `three-column`

Closest external analogs:

- `gufranco/tmux-tiling-revamped`
  - File:
    - `src/lib/layouts/main-center.sh`
  - Nearest analog:
    - three vertical bands with computed pane distribution
  - Behavior:
    - Full custom layout projection from pane order
    - No semantic `new-pane` insertion logic
  - Takeaway:
    - External precedent points toward reprojection, not exact birth placement

- `jhornsberger/tmux-relative-layout`
  - File:
    - `layout.tmux`
  - Nearest analog:
    - `main_vertical_tiled_layout`
  - Behavior:
    - Calls `select-layout main-vertical`
    - Then runs `move-pane -h` on alternating panes
    - Then resizes the resulting bands
  - Takeaway:
    - This is explicit post-split pane movement to realize a non-native multi-column pattern

Overall conclusion for `three-column`:

- No exact external analog was found in the surveyed set
- The nearest precedents all accept explicit post-birth rearrangement
- I did not find a surveyed plugin that births directly into a three-column semantic tail

### `even-horizontal`

Closest external analogs:

- `2KAbhishek/tmux-tilit`
  - File:
    - `tilit.tmux`
  - Analog: built-in `even-horizontal`
  - Behavior:
    - Uses generic split bindings for pane creation
    - Binds a layout key that switches to `even-horizontal`
    - On `after-split-window` and `pane-exited`, runs `select-layout; select-layout -E`
  - Takeaway:
    - This delegates creation-time behavior to tmux and accepts full row equalization afterward

- `gufranco/tmux-tiling-revamped`
  - File:
    - `src/lib/layouts/deck.sh`
  - Analog: equal-width full-height cards
  - Behavior:
    - Re-applies `select-layout even-horizontal`
    - Does not attempt layout-aware new-pane birth
  - Takeaway:
    - External precedent for this family is “split however tmux split, then equalize the row”

Overall conclusion for `even-horizontal`:

- Surveyed plugins treat this as a built-in equalization problem, not a semantic insertion problem

### `even-vertical`

Closest external analogs:

- `2KAbhishek/tmux-tilit`
  - File:
    - `tilit.tmux`
  - Analog: built-in `even-vertical`
  - Behavior:
    - Uses generic split bindings for pane creation
    - Binds a layout key that switches to `even-vertical`
    - On split or close, delegates to built-in layout equalization
  - Takeaway:
    - Same pattern as `even-horizontal`

Overall conclusion for `even-vertical`:

- I did not find a surveyed plugin with a smarter birth-first vertical-column insertion strategy
- The external norm is to re-equalize the full column after split

### `grid`

Closest external analogs:

- `gufranco/tmux-tiling-revamped`
  - File:
    - `src/lib/layouts/grid.sh`
  - Behavior:
    - Calls built-in `select-layout tiled`
    - Reapplies on `after-split-window`
  - Takeaway:
    - Explicitly accepts tmux-global retiling after creation

- `2KAbhishek/tmux-tilit`
  - File:
    - `tilit.tmux`
  - Behavior:
    - Binds a layout key for `tiled`
    - Uses generic splits and generic post-split layout equalization
  - Takeaway:
    - Same broad pattern as `tmux-tiling-revamped`

Overall conclusion for `grid`:

- I did not find any surveyed plugin trying to birth directly into the final grid cell
- External precedent treats grid as a global retile problem

### `spiral`

Closest external analogs:

- `emretuna/tmux-layouts`
  - Files:
    - `scripts/new_pane.sh`
    - `scripts/apply_layout.sh`
    - `scripts/layout_engine.sh`
    - `README.md`
  - Behavior:
    - `new_pane.sh` keeps `@tmux_layouts_spiral_last`
    - It targets the previously stored tail pane
    - It alternates split axis based on current pane count
    - The README explicitly says the spiral structure is created by the split sequence
    - `layout_engine.sh` for `spiral` only resizes the leader pane; it does not reconstruct the whole tree
  - Takeaway:
    - This is the strongest surveyed precedent for “birth the pane in the right recursive branch first”
    - It is the clearest evidence that a spiral-like layout can use layout-aware `new-pane` rather than full reprojection

- `gufranco/tmux-tiling-revamped`
  - Files:
    - `src/lib/layouts/spiral.sh`
    - `src/lib/layouts/dwindle.sh`
    - `tmux-tiling-revamped.tmux`
    - `src/tiling.sh`
  - Behavior:
    - Uses `after-split-window` to reapply the layout
    - `_apply_bsp_layout "true"` computes a full BSP layout string
    - `_bsp_fix_pane_order` then uses `swap-pane` because spiral leaf order diverges from pane index order
  - Takeaway:
    - This is the strongest surveyed precedent for accepting both full geometry reprojection and explicit post-layout pane swaps for spiral

Overall conclusion for `spiral`:

- The surveyed ecosystem shows both viable strategies:
  - birth-first recursive insertion
  - generic split followed by full BSP reprojection and swap correction

### `dwindle`

Closest external analogs:

- `gufranco/tmux-tiling-revamped`
  - Files:
    - `src/lib/layouts/dwindle.sh`
    - `tmux-tiling-revamped.tmux`
    - `src/tiling.sh`
  - Behavior:
    - Uses `after-split-window` to reapply the layout
    - `_apply_bsp_layout "false"` computes a full BSP layout string from pane order
    - For dwindle, the leaf permutation is identity, so pane-order repair swaps are not needed
  - Takeaway:
    - This is strong external precedent for “full reprojection is acceptable, but reorder churn can sometimes be avoided when leaf order already matches pane order”

- `gufranco/tmux-tiling-revamped`
  - File:
    - `src/lib/operations/autosplit.sh`
  - Behavior:
    - Provides an on-demand longest-axis split helper
    - This is not a layout-specific `new-pane` insertion path
  - Takeaway:
    - It is not evidence of a dwindle-aware birth strategy

Overall conclusion for `dwindle`:

- In the surveyed set, the only exact analog relies on full BSP reprojection after split
- I did not find a second plugin implementing a dwindle-specific birth-first `new-pane`

### `monocle`

Closest external analogs:

- `saysjonathan/dwm.tmux`
  - Files:
    - `bin/dwm.tmux`
    - `lib/dwm.tmux`
    - `README.md`
  - Behavior:
    - Monocle is `resize-pane -Z`
    - In monocle mode, the internal `$layout` string becomes:
      - `select-layout main-vertical`
      - `resize-pane -t :.0 -x ${mfact}%`
      - `resize-pane -Z`
    - `newpane()` still does split -> swap -> reapply layout -> re-zoom
    - `nextpane()` and `prevpane()` also re-zoom after focus moves
  - Takeaway:
    - This plugin accepts structural churn under the hood and hides it by ending in zoom

- `gufranco/tmux-tiling-revamped`
  - Files:
    - `src/lib/layouts/monocle.sh`
    - `src/tiling.sh`
  - Behavior:
    - `apply_layout_monocle()` just toggles `resize-pane -Z` and remembers the previous layout
    - `_handle_hook()` intentionally does nothing for `monocle` on split, kill, or resize
  - Takeaway:
    - This plugin relies on tmux zoom behavior rather than reprojecting monocle after every split

- `gufranco/tmux-tiling-revamped`
  - File:
    - `src/lib/layouts/deck.sh`
  - Nearest related pattern:
    - equal-width full-height cards instead of true fullscreen
  - Takeaway:
    - This is a useful adjacent precedent for “hide vertical churn by keeping panes full height” rather than zooming

Overall conclusion for `monocle`:

- Surveyed plugins do not solve creation-time churn by exact geometric birth
- They either:
  - re-zoom after structural churn, or
  - rely on zoom to hide most of the churn in the first place
