# Verification

AnimLayers follows workflowCompass. `compass.json` extends the `roblox` preset and adds the package's
own checks; run them through compass.

```powershell
rokit install
pesde install --locked
compass checks run -ProjectRoot . -Kind code
compass checks run -ProjectRoot . -Kind docs    # needs npm ci once
```

## The checks

| Check | What it runs |
| --- | --- |
| `stylua`, `selene` | the pinned StyLua and Selene over `src`, `tests` and `dev` |
| `layout`, `source`, `robloxLayout`, `robloxSource` | compass's file layout and source rules |
| `analyze` | luau-lsp with the new solver over `src`, `dev`, and the `*.typecheck.luau` and `*.typeError.luau` files |
| `gameMirror` | the `game/` mirror matches `dev.project.json` |
| `robloxPackageRequires` | the installed dependency requires by string |
| `tests` | `scripts/verify/tests.ps1`: every `*.spec.luau` in Lune and every `*.tests.ps1` in PowerShell, each in its own process |
| `docs` | `npm run docs:build` |
| `studio` | manual: [Studio verification](./studio-verification.md) |

`selene.toml` names `seleneLuau.yml` before the Roblox standard library. That file corrects one
global for the pinned Selene: `require` takes a string.

## The tests

| File | States |
| --- | --- |
| `tests/src/controllers/layerController/layerController.spec.luau` | the controller through the package entry, over the fake `Animator` |
| `tests/src/controllers/layerController/layerController.typecheck.luau` | calls the public types accept |
| `tests/src/controllers/layerController/layerController.typeError.luau` | calls they refuse, one `-- expect-error` per line |
| `tests/src/utils/clipDefinition/clipDefinition.spec.luau` | what a definition holds and refuses |
| `tests/scripts/verify/tests.tests.ps1` | the test runner itself |

Fixtures, both in `tests/` because they stand in for the platform and for nothing in the package:

- `robloxEnvironment.fixture.luau` installs `Instance`, `Enum` and Roblox's datatypes from
  `@lune/roblox`, so the real modules load under Lune.
- `fakeAnimator.fixture.luau` is a stand-in `Animator` whose tracks do only what a test tells them
  and log every engine call.

Run one file with `scripts/verify/tests.ps1 -Filter layerController`.

## The allocation case

The last case of `layerController.spec.luau` shows that `update` allocates nothing. It reads
`collectgarbage("count")` before and after 500 steps, ten times, and takes the largest growth, for
two kinds of step: a bare `update` with three layers playing and nothing changed, and a `setClipSpeed`
beyond the tolerance followed by `update`. Each must stay below 2 KB. One table, closure or string
of 40 bytes per step would grow the heap by 20 KB. The fake `Animator` has its logging turned off
for the case, and the case also asserts that the quiet updates made no engine call and that each
changing one made exactly one.

It measures Lune's Luau. Roblox's VM is measured in Studio.

## What these checks cannot show

Lune has no engine. Whether a replayed track starts from 0, in which order `Stopped` and `Ended`
arrive, what a marker signal does on a kept track, and what a loaded track costs are all
[Studio verification](./studio-verification.md).
