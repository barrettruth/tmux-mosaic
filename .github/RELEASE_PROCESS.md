# tmux-mosaic release process

This repository uses a dev-version-on-main workflow with GitHub Actions handling
nightly prereleases, stable tags, GitHub Releases, and the follow-up bump back
to the next dev version.

## Version model

- `flake.nix` is the source of truth for the current version.
- Main normally carries a dev version such as `0.1.0-dev`.
- Stable releases use plain semver such as `0.1.0`.
- Stable tags are prefixed with `v`, for example `v0.1.0`.
- After a stable release, main should return to the next patch dev version such
  as `0.1.1-dev`.

The repo helper script is `scripts/release-version.sh`.

Useful commands:

```bash
scripts/release-version.sh get
scripts/release-version.sh assert-dev
scripts/release-version.sh assert-stable 0.1.0
scripts/release-version.sh base 0.1.0-dev
scripts/release-version.sh next-patch-dev 0.1.0
scripts/release-version.sh tag 0.1.0
scripts/release-version.sh set 0.1.0
```

## Stable release flow

Start from a clean `main` that already passed the `quality` workflow and is at a
dev version.

### 1. Resolve the release versions

```bash
current="$(scripts/release-version.sh get)"
version="$(scripts/release-version.sh base "$current")"
next_dev="$(scripts/release-version.sh next-patch-dev "$version")"
printf 'current=%s\nrelease=%s\nnext_dev=%s\n' "$current" "$version" "$next_dev"
```

For example, `0.1.0-dev` prepares `0.1.0`, then rolls main forward to
`0.1.1-dev`.

### 2. Open the release PR

Dispatch the `Prepare Release` workflow:

```bash
gh workflow run release_prepare.yaml \
  --repo barrettruth/tmux-mosaic \
  -f version="$version" \
  -f next_dev_version="$next_dev"
```

That workflow:

- validates the current, stable, and next-dev versions
- sets `flake.nix` to the stable version
- creates or updates `release/v$version`
- opens or updates `chore(release): prepare v$version`
- applies the `skip-release-notes` label

### 3. Merge the release PR

Review the generated PR normally and merge it into `main` once CI is green.

### 4. Let automation publish the release

After the `quality` workflow succeeds on the stable-version commit on `main`,
the `Publish Release` workflow automatically:

- reads the stable version from `flake.nix`
- creates the annotated git tag `v$version` if it does not already exist
- generates release notes with GitHub Releases note generation
- creates or updates the GitHub Release for `v$version`
- opens or updates a follow-up PR that bumps `main` to the next dev version

### 5. Merge the next-dev PR

Merge the generated `chore(release): start <next-dev-version>` PR so `main`
returns to a dev version.

### 6. Verify the final state

Confirm all of the following:

- `main` is back on a `-dev` version
- the stable tag exists
- the stable GitHub Release exists with generated notes
- no release PR or next-dev PR is left hanging unexpectedly

## Nightly prereleases

While `main` carries a dev version, the `Nightly Release` workflow can publish a
moving `nightly` prerelease from the latest successful `quality` run on `main`.

You can trigger it manually with:

```bash
gh workflow run release_nightly.yaml --repo barrettruth/tmux-mosaic
```

The nightly workflow:

- only publishes when the current version is a dev version
- deletes and recreates the `nightly` tag if the target commit changed
- generates notes against the latest stable tag when one exists
- creates the `nightly` GitHub Release as a prerelease and marks it non-latest

## Release notes

Stable and nightly release notes use GitHub Releases generated notes.

- Categories are defined in `.github/release.yml`.
- PRs or issues with the `skip-release-notes` label are excluded.

## Maintainer checklist

Before cutting a stable release:

1. Confirm the v0.1 tracker and blocking issues are actually done.
2. Confirm the current `main` version is a dev version.
3. Confirm `quality` is green on the target `main` commit.
4. Run the `Prepare Release` workflow with the resolved versions.
5. Merge the release PR.
6. Wait for `Publish Release` to create the stable tag and GitHub Release.
7. Merge the generated next-dev PR.
8. Verify `main` is back on the expected next dev version.
