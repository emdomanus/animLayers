# AnimLayers repository guide

AnimLayers follows workflowCompass: `compass.json` extends the `roblox` preset, and the compass skills
apply.

## Repository map

- `src/` is the package. Every module in it runs on the server and on the client, so the package is
  entirely shared: no module sits in a `shared`, `server` or `client` folder, and its one entry is
  `src/shared.luau`, the `lib` `pesde.toml` names.
- `tests/` mirrors the repository: `tests/src/...` tests the package through its entry, and
  `tests/scripts/...` the scripts. The two fixtures in `tests/` stand in for Roblox.
- `dev/client/` is the client of the dev place, `dev.project.json`: the game `compass.json` names as
  `rojoProject`.
- `scripts/verify/tests.ps1` runs every `*.spec.luau` in Lune and every `*.tests.ps1` in PowerShell.
- `docs/` holds the package documentation; start with `docs/index.md`. `docs/todo/` holds the open
  task records.
- Generated local state: `luau_packages/`, `game/`, `sourcemap.json`, `node_modules/`,
  `.verification/`.

## Checks

Tools resolve from `~/.rokit/bin`, as `rokit.toml` pins them. Once per checkout:

```powershell
rokit install
pesde install --locked
compass roblox gameMirror -ProjectRoot .
```

Then:

```powershell
compass checks run -ProjectRoot . -Kind code
compass checks run -ProjectRoot . -Kind docs
```

The `docs` check needs `npm ci` first. The `studio` check is manual:
`docs/guides/studio-verification.md`.
