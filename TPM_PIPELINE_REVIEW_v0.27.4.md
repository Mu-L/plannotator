# guides.show Pipeline Review

Plannotator v0.27.4 release cycle · August 17, 2026 · prepared for TPM evaluation · AI-assisted under maintainer direction

**Summary.** Plannotator v0.27.4 shipped on August 17 with a new externally hosted service, guides.show, in its release path. During release preparation we found and fixed two latent pipeline defects: the CI credential for publishing to guides.show had never had write permission (every prior publish was done manually from a maintainer laptop), and the deployment environment's branch policy silently blocked the tag-triggered deploy that the design depends on. Both are corrected and the full tag-to-production path has now executed end to end once. This document explains the product surface, the pipeline as it stands, what changed, and the items that need your evaluation.

## What guides.show is

Plannotator's code review tool can generate a **Guided Review**: an agent-authored walkthrough of a changeset, organized into ordered chapters with prose and diffs. As of v0.27.4, a guide can leave the tool in three ways:

- **Portable download.** One HTML file containing the guide content and the diff. The rendering application (the "viewer") is not embedded; the file loads it from guides.show, pinned by exact filename and cryptographic checksum (subresource integrity), so a substituted viewer will not execute. Offline, the file degrades to a plain-text rendering.
- **Share link.** The guide is uploaded to guides.show and anyone with the link can open it in a browser. Uploads are end-to-end encrypted by default: the decryption key travels in the URL fragment, which browsers do not send to servers, so the service stores ciphertext it cannot read. Creating a share returns a one-time delete token (stored server-side only as a hash). An opt-in checkbox stores a guide unencrypted to allow link previews; encrypted is the default. The environment variable `PLANNOTATOR_SHARE=disabled` turns the entire capability off for an installation.
- **CLI authoring.** `plannotator guide list | export | share | unshare` lets scripts and agents produce and publish guides without a browser.

**Infrastructure.** guides.show is a Cloudflare Worker with R2 object storage, in the maintainer's Cloudflare account. Two storage roles: user shares (runtime writes by the Worker) and viewer application files (written only by the release pipeline). Viewer publishing is add-only and content-hashed: a deploy can add new files but can never overwrite or delete an existing one, so published share links cannot be broken by later deploys. Share creation is rate limited per IP. Retention of shared guides is currently indefinite by explicit maintainer decision, flagged for revisit; deletion exists via the per-share delete token. The product collects no telemetry.

## The release pipeline

Pushing a version tag (`v*`) triggers two workflows in the GitHub repository:

```
Tag push v0.27.4
├── release.yml
│   ├── Test suite
│   ├── 12 cross-compiled binaries (6 platforms, app + paste service)
│   ├── SLSA provenance attestations, CycloneDX SBOM, Grype gate
│   ├── Immutable GitHub Release
│   └── npm publish with provenance (opencode + pi-extension)
└── guides-show-deploy.yml
    ├── Build viewer, size budgets, manifest pin check
    ├── Add-only publish to R2
    └── Deploy Worker + landing, smoke the published viewer
```

Compliance-relevant properties already in place: binaries carry SLSA build provenance signed through Sigstore and recorded in Rekor; the pipeline publishes and attests a CycloneDX SBOM with a Grype vulnerability gate (first shipped in v0.27.3); GitHub Immutable Releases means a published tag's commit and asset bindings are permanent and a bad release must be superseded, never rewritten; npm packages publish with provenance. The viewer pin that exports depend on is enforced twice: PR CI fails if the committed pin does not match the built viewer, and the deploy refuses to publish a build that does not match the pin.

## What we found and fixed this cycle

### 1. The CI publish credential never had write access

The guides.show deploy workflow had never completed successfully. Its Cloudflare API token could read the viewer bucket but received `403 Authentication error` on writes. This went unnoticed because every viewer publish to date had been performed manually with a maintainer's personal OAuth session, which masked the broken automation. It surfaced when release QA live-probed the viewer file the release candidate pins and got a 404. The maintainer added `Workers R2 Storage: Edit` to the token and the workflow then passed end to end, including its post-publish smoke check.

> **Runbook note.** If `CLOUDFLARE_API_TOKEN` (GitHub environment: `production`) is ever rotated, the replacement needs: Workers Scripts Edit, Workers Routes Edit, KV Edit, and R2 Edit. This requirement currently lives in chat history and this document only.

### 2. The environment policy silently blocked tag deploys

The `production` GitHub environment restricted deployments to the `main` branch. Release tags are not branches, so every tag-triggered deploy was rejected before its first step, with a failure that reads as an empty job. The designed primary trigger for viewer publishing had therefore never been able to run. Fixed by adding a `v*` tag rule to the environment's deployment branch policy: the rerun under the tag then executed its full step sequence, which verifies the policy fix. The first rerun's R2 upload hit a Cloudflare API outage (HTTP 521 from Cloudflare's own gateway) that was ongoing that day; a retry once Cloudflare recovered completed green, so the tag-triggered deploy has now executed end to end under the v0.27.4 tag. No user impact at any point: all assets this release pins were already published and verified live by an earlier manual run of the same workflow from the same tree. Config change made via the GitHub API on August 17, additive and reversible.

### 3. Build environment drift produced divergent artifacts locally

A long-lived development checkout was found building the viewer to different bytes than CI from identical source: its package store had accumulated stale duplicate dependency versions over months, and the discrepancy was initially misdiagnosed as an OS-level difference. Containment held: nothing user-facing was affected, because binaries build only in CI and the viewer pin is validated by CI gates on every PR and at deploy. A clean reinstall reproduced CI byte-for-byte. Two durable mitigations landed: PR CI now uploads the built viewer manifest as an artifact so the authoritative hashes are always retrievable, and the regeneration runbook now requires a frozen-lockfile install.

### 4. Release executed during a GitHub partial outage

GitHub reported degraded service through the day (API 503 waves, one deploy run killed before its first step). The release was gated on component status at two points: Actions, API, Packages, and Webhooks were operational at tag time, and only Git Operations showed degraded performance, which is safe because a tag push is atomic. All outage-induced failures were retried to success; none required manual intervention beyond reruns.

## Changes made, at a glance

| Change | Where | Status |
| --- | --- | --- |
| R2 write permission added to CI token | Cloudflare dashboard (maintainer) | Done, verified |
| Tag rule `v*` added to deploy policy | GitHub `production` environment | Done, verified (job now executes under tags) |
| Viewer manifest published as CI artifact | `.github/workflows/test.yml` | Merged in #1338 |
| Per-IP rate limit on share creation | guides.show Worker | Shipped in #1324 |
| Binary/npm release path executed end to end under the tag | `release.yml` | All jobs green at v0.27.4 |
| Tag-triggered guides deploy green end to end | `guides-show-deploy.yml` | Done: completed under the v0.27.4 tag after a Cloudflare outage retry |

## Open items for your evaluation

1. **Secrets inventory and rotation.** The Cloudflare token's required permission set should live in a runbook you own, not in chat history. Related: which secrets exist across the repo's environments, who owns rotation, and on what cadence.
2. **Retention policy for shared guides.** Indefinite retention is a deliberate product decision, not an oversight, but it is undocumented outside the decision record and worth a formal position (encrypted-by-default materially changes the exposure analysis).
3. **The between-releases publish gap.** A merge to main can change the viewer the code pins before any release publishes it; shares made from source builds in that window point at an unpublished viewer. The maintainer chose to keep publishing coupled to release tags (manual dispatch as escape hatch) rather than auto-deploy on merge. Affects developers running from source only, never released binaries.
4. **Install script distribution.** plannotator.ai serves install scripts from an S3 bucket that CI deliberately cannot write; sync is manual with local credentials. This is a considered trade (no CI blast radius into the install path) but it is an unaudited manual step in the distribution chain. Verified in-sync at this release.
5. **Environment policy audit.** The tag-rule gap existed because environment protection settings are invisible to code review. A periodic check that workflow triggers and environment policies agree would have caught it at creation.

---

Plannotator v0.27.4 · tag `2a22e580` · release and npm artifacts verified live · guides.show deploy run 32053539185 completed under the tag after the policy fix. Questions on product behavior: the decision records in `adr/` (portable guided reviews, guide share hosting) are the authoritative source.
