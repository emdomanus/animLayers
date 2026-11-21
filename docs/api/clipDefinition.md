# clipDefinition

```luau
AnimLayers.utils.clipDefinition.build(assetId: number, looped: boolean): ClipDefinition
```

Builds one frozen definition:

```luau
ClipDefinition = {
	read assetId: number,
	read looped: boolean,
}
```

- `assetId` must be a whole number above 0; anything else raises.
- `build` also creates the definition's one `Animation` Instance, with `AnimationId`
  `"rbxassetid://<assetId>"`. Every controller that plays the definition loads its tracks from that
  Instance. It is carried on the definition under a field the public type does not declare, and
  nothing in the package destroys it.
- A definition must come from `build`. A table written by hand has no `Animation`, and the `update`
  that would load its track raises.
- Build each definition once, when your code loads, and play the same definition on every
  controller. A second `build` with the same arguments is a second definition with its own
  `Animation`, and a controller keeps separate tracks for it.
- The loop flag belongs to the definition. To play one asset both looping and once, build two
  definitions.
