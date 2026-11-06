# CrossMono website agent guide

This repository is https://crossmono.github.io: the install page with the web flasher for CrossMono, firmware for
the M5Stack PaperMono and PaperMono-Lite. The firmware, its decisions and its full agent rules are in
[nandanito/crossmono](https://github.com/nandanito/crossmono) (`CLAUDE.md`, `RELEASING.md`, `docs/decisions/`,
ADR 0009 for install). Where this file says nothing, those rules apply. Maintainer: Nandan.

## What is here

- `index.html`: the whole page, no build step. ESP Web Tools is loaded from unpkg at an exact version.
- `manifest.json` (stable) and `manifest-rc.json` (test build): what the install buttons use.
  `firmware/<tag>/`: the full image, the release manifest, the licence file and `SHA256SUMS`. See [firmware/README.md](firmware/README.md).
- `.github/workflows/pages.yml` deploys the site on every push to `main`. Only `index.html`, the two manifests and
  `firmware/` are served; a new file to serve must be added to its "Collect the site" step.
- `.github/workflows/publish-firmware.yml` (run by hand with a tag) copies a release into `firmware/<tag>/`,
  updates the manifests through `scripts/publish-firmware.sh`, commits to `main` as github-actions[bot] (unsigned)
  and deploys. A branch rule on `main` that requires PRs or signed commits would block that push; give the bot a
  bypass first.

## Rules

- **Merging to `main` publishes the site.** Ask Nandan before every merge, push, workflow run and Pages setting
  change. Never run `publish-firmware` without his go-ahead, and never create tags or releases.
- Branch → PR → merge commit. Semantic PR titles (`feat:`, `fix:`, `docs:`, `chore:`). Commits are SSH-signed through
  1Password; if signing fails, ask Nandan to unlock 1Password; never bypass signing. No assistant trailers.
- Do not edit `firmware/` or the two manifests by hand; the workflow owns them.
- Use the wording from ADR 0002: "CrossMono is independent community firmware. It is not affiliated with or
  supported by M5Stack. PaperMono is a product of M5Stack."
- The page tells users what a USB install erases (Bluetooth pairings, keys of protected books) and what stays
  (books, settings and Wi-Fi on the SD card; OTA erases nothing). Keep that in step with the firmware.
- Plain English for non-native readers. Test in a copy of the site outside the repository: run
  `scripts/publish-firmware.sh <tag> <dir>` there on downloaded release files (or a release workflow dry-run
  artifact), then `python3 -m http.server` (localhost is a secure context for Web Serial).
- Hardware tests (flashing a device from the page) are Nandan's.
