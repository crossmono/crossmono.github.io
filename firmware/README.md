# Firmware folders

The web flasher serves CrossMono's full image from this site, so the browser loads it from the same origin.

- Each published release has a folder `firmware/<tag>/`, for example `firmware/0.1.0-rc.1/`, with four files from
  the GitHub release in [nandanito/crossmono](https://github.com/nandanito/crossmono/releases), unchanged:
  - `crossmono-<tag>-papermono-full.bin`: the full image, written at offset 0x0
  - `manifest.json`: the release's ESP Web Tools manifest (one part, the full image, path relative to it)
  - `crossmono-<tag>-LICENSE.txt`: every licence of the image and the source commits. The page links to it from
    the release's card and from the footer, because the site serves the image too.
  - `SHA256SUMS`: the release's checksums. It also lists the OTA image and the ELF, which are not copied here, so
    check with `sha256sum -c --ignore-missing SHA256SUMS`.
- `manifest.json` (stable) and `manifest-rc.json` (test build) at the site root are copies of a release manifest
  with the part path rewritten to `firmware/<tag>/crossmono-<tag>-papermono-full.bin`. The page's install buttons
  use them. With no release in a channel, the file has an empty `version` and no `builds`, and the page shows
  "no release yet" for it.
- Publishing a final release clears `manifest-rc.json` when its candidate is for that release or an older one.
- A publish keeps the folders that the two manifests point at, and the ones they pointed at before it; it deletes
  the rest. GitHub Pages and its CDN cache files for 10 minutes, so a cached old manifest can still point at the
  previous folder for a while. Publishing the same tag again deletes nothing. Leave 10 minutes between publishes of
  different tags. Older versions stay on the GitHub releases.
- The page installs the manifest it has shown (as a `blob:` URL), so a page left open across a publish still
  installs the version on its button.
- Deleted folders stay in the git history: each publish adds about 6.1 MB to the repository (5.4 MB image, 0.7 MB
  licence file).

Do not edit these files by hand. The `publish-firmware` workflow writes them:

```sh
gh workflow run publish-firmware.yml --repo crossmono/crossmono.github.io -f tag=<tag>
```

It downloads the four files from the release, checks them against `SHA256SUMS`, runs
`scripts/publish-firmware.sh`, commits to `main`, and deploys the site.
