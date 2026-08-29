# Security policy

## Reporting a vulnerability

Please use [GitHub's private vulnerability reporting](https://github.com/katalor-group/katalor-ci-floor/security/advisories/new)
for this repository rather than a public issue. This lets us assess and fix a real
finding before it's visible to anyone who might act on it first.

## Scope

This repo hosts reusable, org-wide CI workflows (secret scanning) called by other
repositories. In scope: anything in the workflow files or the pre-push hook script
that could weaken the scan itself, leak scanned content, or let a caller's
credentials be reached unexpectedly. Out of scope: findings in the third-party
actions this repo calls (`actions/checkout`, `trufflesecurity/trufflehog`) --
report those upstream.

## Supported versions

Only the current major tag (see the repository's tags) is supported. Callers
pinned to an older major tag should update rather than expect a backport.
