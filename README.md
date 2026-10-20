# katalor-ci-floor

Public, reusable GitHub Actions workflows for the org-wide CI security floor --
checks generic enough to be shared verbatim across every Katalor property and
client repo, including across organizations (`katalor-group`, `katalor-clients`),
which a private repo's reusable workflows cannot be called from.

**Only generic, non-property-specific checks belong here.** Nothing that reflects
review judgment, prompts, or property-specific logic (that lives in the private
`katalor-group/katalor-ci`). If a check needs a property's own secret, config, or
context beyond what `workflow_call` inputs can carry cleanly, it does not belong in
this repo -- open an issue and it'll get a home in the right place instead.

## What's here

- **`secret-scan.yml`** -- reusable workflow, verified-secret scanning (TruffleHog)
  against a pull request's diff.
- **`weekly-full-history-sweep.yml`** -- reusable workflow, the same scanner against
  full git history. Called from each property's own scheduled trigger (a reusable
  workflow can't schedule itself).
- **`scripts/install-git-guards.sh`** -- one-time local installer for a pre-push
  hook that runs the same scan before a push leaves the machine, not just before a
  PR merges.

## Using it

In a calling repo's own workflow file:

```yaml
name: Secret Scan
on:
  pull_request:
    types: [opened, synchronize]
jobs:
  scan:
    uses: katalor-group/katalor-ci-floor/.github/workflows/secret-scan.yml@v1
    permissions:
      contents: read
```

```yaml
name: Secret Scan (weekly)
on:
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch: {}
jobs:
  sweep:
    uses: katalor-group/katalor-ci-floor/.github/workflows/weekly-full-history-sweep.yml@v1
    permissions:
      contents: read
```

**Always reference `@v1` (or whatever the current major tag is), never `@main`.**
The major tag only moves through review; `main` can carry unreviewed commits.

Local pre-push guard, once per clone:

```
curl -sSL https://raw.githubusercontent.com/katalor-group/katalor-ci-floor/v1/scripts/install-git-guards.sh | bash
```

## What a green scan means

A passing scan means **no live credential was found**. The scan reports only results TruffleHog could verify as active
(`--results=verified,unknown`: a verified live secret, or one whose verifier could not decide). It does not report a
revoked key, or a secret type that has no verifier, and it does not report a well-known example key. AWS's documented example
access key, for instance, passes. That is by design: a scanner that blocks on noise trains people to override it. It is a floor
against leaked live credentials, not a guarantee that no secret-shaped string exists in a diff.

## Scanner version and time limits

- The scanner is pinned to a release **and** an image digest (`version: "3.99.0@sha256:..."` in both workflows), not `latest`. The
  action runs `"${image}:${version}"`; a `tag@digest` reference is resolved by the digest. Bump it by PR, together with the action's
  commit pin (Dependabot moves the action pin only).
- Jobs are bounded: the diff scan at 10 minutes, the weekly full-history sweep at 30. A normal diff scan runs under 30 seconds.
- `@v1` is a tag. A change merged to `main` reaches no adopter until the `v1` tag is moved to a reviewed commit, and moving it
  changes every adopter at once, so it is a deliberate release step, not part of a routine merge.

## Why TruffleHog

Verifies whether a match is a live, active credential, not just a regex hit --
materially fewer false positives than pattern-matching alone, which matters because
a scanner that blocks on noise trains people to stop trusting (and eventually
override) it. No license key to hold or rotate. Full reasoning in
`.github/workflows/secret-scan.yml`'s own header comment.

## Reporting a vulnerability

See [SECURITY.md](SECURITY.md).
