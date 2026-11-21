# Backlog

Open after the VMMO-90 rewrite.

## Needs Studio

- The whole [Studio checklist](/guides/studio-verification). Nothing in it has been run on the new
  controller.
- Allocation per frame in Roblox's VM, with the VMMO-45 method.
- The memory cost of a loaded, idle `AnimationTrack`, which decides whether 64 kept tracks per
  controller is the right cap.
- Whether `Ended` fires for a track whose `Animator` has left the DataModel.

## Not built

- A blend along one number, and one along two. `docs/todo/vmmo90/apiAssessment.md` section 4.3
  records the definitions, the weights, and that clips of different lengths stay in phase only if
  each track's speed is scaled by its length. When that page is deleted, move the record here.
- A way to play one of Roblox's own animation graphs as a clip and forward a parameter to
  `AnimationTrack:SetParameter`. Nothing asks for it yet.

## Consumer

- VoxelMMO keeps its pin of the 0.1 revision under a legacy name and adds this one as `animLayers`. How pesde links a
  `luau` dependency (`luauUtils`) of a `roblox` package inside VoxelMMO's DataModel has not been
  tried: the package requires it as `../../../luau_packages/luauUtils`, which resolves in the dev
  place because `dev.project.json` maps `luau_packages` beside the package.
