# omarchy-zkagent

An Omarchy bar widget for `zkagent`: the last attestation verdict, on your desktop.

```
ZK      cyan, accepted      the newest receipt verified, and it is recent
ZK!     red, rejected       with the reason code in the tooltip, e.g. public_input_mismatch
ZK?     amber, unverifiable could not verify: the artifact or the keys are wrong, not the claim
ZK      grey, stale or none older than 15 minutes, or no verdict yet
```

The state is never a check mark. The mark is the project's "ZK", coloured, with `!` for rejected and
`?` for could-not-verify, so it reads the same in greyscale.

The grey state is the point. A green check that is a week old is worse than no check, so age
is a first-class state rather than a detail: after `staleAfterSec` (default 900) the widget
stops claiming anything.

## Install

```bash
omarchy plugin add https://github.com/MCPVOT/omarchy-zkagent.git --enable
```

Then place it on the bar:

```bash
omarchy bar use mcpvot.attest left
```

Remove with `omarchy plugin remove mcpvot.attest`.

## What it reads

One file, `~/.local/state/zkagent/last-verdict.json`, containing exactly what
`zkagent verify --json` prints:

```json
{"execution_id": 1002, "format": 3, "reason": null, "reason_code": null, "verdict": "accept"}
```

Nothing is parsed out of English and nothing is executed on read. The widget also never
writes: the file belongs to whoever runs verification.

Produce it from a timer, for example:

```bash
zkagent --json verify --keys ~/.config/zkagent/keys \
  --policy policy.json --receipt receipt.json --proof proof.json \
  > ~/.local/state/zkagent/last-verdict.json
```

Or from Hermes, where the `zkagent-attest` plugin writes the same document on every
`zkagent_verify` call.

## Settings

| key | default | meaning |
| --- | --- | --- |
| `statusFile` | `~/.local/state/zkagent/last-verdict.json` | the verdict document |
| `refreshIntervalSec` | `60` | re-read interval |
| `staleAfterSec` | `900` | after this, the verdict shows grey |
| `command` | empty | optional, run on click; it should rewrite the verdict file |

```bash
omarchy bar set mcpvot.attest staleAfterSec 300
```

## Licence

MIT. The protocol lives in [MCPVOT/zkagent](https://github.com/MCPVOT/zkagent); the Hermes
plugin that produces these verdicts lives in
[MCPVOT/hermes-zkagent](https://github.com/MCPVOT/hermes-zkagent).

## Does it show an avatar in the app launcher?

Omarchy plugin manifests have no icon field: the discovery contract is `id`, `name`, `description`,
`kinds`, `entryPoints` and the bar paths. A bar widget's identity is its glyph, which is why this one
shows `ZK` rather than a picture. Nothing is missing from the manifest.

If you want zkagent to appear in the application launcher with the project mark, that is a desktop
entry, not a plugin:

```bash
install -Dm644 assets/zkagent.svg ~/.local/share/icons/hicolor/scalable/apps/zkagent.svg
# then a .desktop with: Exec=foot -e zkagent-status   Icon=zkagent
```

`zkagent-status` prints the same verdict the widget shows, so the launcher icon is a real entry point
rather than a shortcut to nothing.
