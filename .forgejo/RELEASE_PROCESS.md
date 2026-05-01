# tmux-mosaic release process

This repository uses a dev-version-on-main workflow with Forgejo Actions
handling nightly prereleases, stable tags, Forgejo releases, and the follow-up
bump back to the next dev version.

## Version model

- `flake.nix` is the source of truth for the current version.
- Main normally carries a dev version such as `0.1.2-dev`.
- Stable releases use plain semver such as `0.1.2`.
- Stable tags are prefixed with `v`, for example `v0.1.2`.
- After a stable release, main should return to the next patch dev version such
  as `0.1.3-dev`.

The repo helper script is `scripts/release-version.sh`.

## Stable release flow

Start from a clean `main` that already passed the `quality` workflow and is at a
dev version.

1. Resolve the release versions:

   ```bash
   current="$(scripts/release-version.sh get)"
   version="$(scripts/release-version.sh base "$current")"
   next_dev="$(scripts/release-version.sh next-patch-dev "$version")"
   printf 'current=%s\nrelease=%s\nnext_dev=%s\n' "$current" "$version" "$next_dev"
   ```

2. Dispatch the `Prepare Release` workflow with `version` and
   `next_dev_version`.

3. Review and merge the generated `chore(release): prepare v$version` PR once
   CI is green.

4. After the stable-version commit is on `main` and the push `quality` checks
   are green, dispatch the `Publish Release` workflow.

   That workflow:

   - creates the annotated git tag `v$version` if it does not already exist
   - creates or updates the Forgejo release for `v$version`
   - opens or updates a follow-up PR that bumps `main` to the next dev version

5. Merge the generated `chore(release): start <next-dev-version>` PR.

## Nightly prereleases

While `main` carries a dev version, the `Nightly Release` workflow publishes a
per-commit nightly prerelease from `main` and refreshes the moving `nightly`
alias. It runs on a daily schedule and can also be dispatched manually.

The workflow refuses to publish unless these push contexts are green for the
target `main` commit:

- `quality / Format (push)`
- `quality / Lint (push)`
- `quality / Test (push)`

There is a manual `skip_quality_check` override for maintainer recovery only.

## Release notes

Forgejo does not provide GitHub's generated-release-notes API. These workflows
generate conservative release notes from the git commit range since the latest
stable tag and include a Forgejo compare link when a previous stable tag exists.
