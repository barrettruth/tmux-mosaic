# Release process

## Versioning

tmux-mosaic uses `vX.Y.Z` tags and a conservative pre-1.0 semver policy.

- `main` is the rolling channel. There are no nightly tags.
- `0.y.0` is for new algorithms, new options, behavior changes, or breaking changes.
- `0.y.z` is for bug fixes, docs, tests, and internal cleanup.
- `1.0.0` is the point where the documented API is considered stable.

The public API is:

- `toggle`, `promote`, `resize-master`, `relayout`
- documented `@mosaic-*` options
- the algorithm contract documented in `README.md`
- `mosaic.tmux` and `@mosaic-exec`

A breaking change is any rename, removal, or incompatible semantic change in that API, including a documented default change that breaks an existing config.

## Changelog and release notes

`CHANGELOG.md` is the source of truth for user-visible changes. Keep new notes under `## Unreleased`, grouped under `Added`, `Changed`, and `Fixed`. When cutting a release, copy those notes into a `## vX.Y.Z - YYYY-MM-DD` section and leave a fresh `## Unreleased` section at the top.

GitHub Releases are cut with `gh` from the matching changelog section. GitHub's auto-generated source tarball and zip are the release artifacts. No separate source archive or release workflow is needed for `v0.x`.

## Exact release commands

From a clean `main` that already contains the release-ready code and docs:

```sh
repo=/path/to/tmux-mosaic
tag=v0.1.0

$EDITOR "$repo/CHANGELOG.md"
$EDITOR "$repo/flake.nix"
direnv exec "$repo" just ci
git -C "$repo" diff -- CHANGELOG.md flake.nix
git -C "$repo" commit -am "chore(release): prepare $tag"
git -C "$repo" tag -a "$tag" -m "$tag"
git -C "$repo" push origin main
git -C "$repo" push origin "$tag"
"$repo/scripts/release-notes.sh" "$tag" > /tmp/tmux-mosaic-release-notes.md
gh release create "$tag" --repo barrettruth/tmux-mosaic --draft --verify-tag --title "$tag" --notes-file /tmp/tmux-mosaic-release-notes.md
gh release edit "$tag" --repo barrettruth/tmux-mosaic --draft=false
```

Before the release commit:

- `CHANGELOG.md` must contain a `## vX.Y.Z - YYYY-MM-DD` section for the tag being cut.
- `flake.nix` must set `version = "X.Y.Z"` in the same release commit.

If tag signing is already configured locally, `git tag -s` is fine in place of `git tag -a`.

## Post-release checklist

- confirm the GitHub Release is published with the matching changelog text
- smoke-test a fresh TPM install
- smoke-test a fresh manual clone and `run-shell`
- confirm a flake input pinned to the release tag or commit evaluates cleanly
- keep an empty `## Unreleased` section at the top of `CHANGELOG.md`
