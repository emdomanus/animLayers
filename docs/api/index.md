# API

Require the package's entry. It hands out two modules, by category, and the public types.

```luau
local AnimLayers = require("@game/ReplicatedStorage/packages/animLayers")   -- the path of your install

AnimLayers.controllers.layerController.new(animator, layerDefinitions)
AnimLayers.utils.clipDefinition.build(assetId, looped)
```

| Export | Reference |
| --- | --- |
| `controllers.layerController` | [layerController](./layerController.md) |
| `utils.clipDefinition` | [clipDefinition](./clipDefinition.md) |

## Types

| Type | Is |
| --- | --- |
| `ClipDefinition` | `{ read assetId: number, read looped: boolean }` |
| `LayerDefinition` | `{ read name: string, read robloxPriority: Enum.AnimationPriority, read fadeIn: number?, read fadeOut: number? }` |
| `LayerController` | the commands and subscriptions |
| `LayerControllerOwned` | `LayerController` with `update`, `clear` and `deconstruct`; what `new` returns |
| `Unsubscribe` | `() -> ()` |

There are no type parameters: a layer is named by a `string` and a play by the `number` that `play`
returned.
