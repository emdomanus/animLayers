# Studio verification

The Lune tests run the controller over a fake `Animator`. Everything below depends on what the
engine really does and has not been run since the package was rewritten. Use
[the dev place](./dev-place.md); record the Studio version with the result.

The checklist that the 0.1 package passed (CP-AG-R, CP-AG-P, CP-TA3) was run on a design that
loaded a new track for every play. It does not carry over.

## Checklist

1. **A replayed track starts over.** "play walk", "stop base", wait for the fade, "play walk": the
   status box shows the same content id starting at `t=0` with its weight rising from 0.
2. **A second track while the first fades.** "play walk again (restarts)": the status box shows two
   tracks of the walk for the length of the fade, then one.
3. **Every end is reported once.** "play wave": one `ended completed` line when the wave ends.
   "stop action" logs one `ended stopped`, "wave, then cheer in the same frame" one `ended replaced`
   for the wave, and "clear" one `ended stopped` for each layer that plays.
4. **No false end after a clear.** "play wave", "clear", "play wave" at once: the first wave logs
   `ended stopped` at the clear, and the second plays through and logs one `ended completed`, at its
   own end. This is the case of a `Stopped` or `Ended` signal arriving after the track was played
   again.
5. **Positions.** "wave from 50%" starts mid-clip. "jump placed on its end (completes)" logs
   `ended completed` in the same frame and the track fades out. "base to 0.2 s" moves the walk.
6. **Backwards.** "wave backwards from its end" on a fresh place, so the track's length has not
   loaded: the wave plays backwards from its end and logs `ended completed` at its start.
7. **Speed.** "speed 2", "speed 0 (pause)", "speed -1 (reverse)" change the status box's speed.
   "speed +0.5% (inside the tolerance)" changes nothing and logs the old speed as the one in effect.
8. **Time scale and weight.** "base time scale 0" freezes the walk and "base time scale 1" resumes
   it from where it was. "base weight 0.3 over 1 s" shows the weight moving for one second. With
9. **Equal priority.** "play wave", then "overlay: cheer at weight 1": the two share the arms
   instead of the later one overriding.
10. **Tracks are kept.** "cycle every clip on action (loads tracks)", twice: the engine's
    `AnimationPlayed` lines appear both times, and nothing warns about a track limit.
11. **Deconstruct.** "deconstruct and build again", then "play walk": it plays; nothing from the
    old controller is logged.
12. **Markers.** With a clip that has a `Footstep` marker in `CLIPS`: one `marker` line per marker
    while the clip is a layer's play, and none while it fades out.
13. **A raise.** Parent the dummy out of `Workspace` before the first play and press "play walk":
    the error appears every frame from `update`; parent it back and the walk starts.

14. **More tracks than the cap on one `Animator`.** The controller keeps 64 tracks. Each of the two
    buttons plays 70 separate definitions of the walk on `action`, so 70 tracks are loaded on the
    dummy's `Animator`. Report what the engine does for each: every line the Output window prints,
    the track count in the status box's first line while it runs and after it settles, and whether
    "play wave" and "play walk" still play afterwards.
    - "70 definitions on action, one per 0.5 s": each earlier track has faded out and is idle
      before the next loads, so from the 65th on the controller destroys the idle track played
      longest ago. Expected from the package: never more than two tracks in the status box. Not
      known: whether the engine reports or keeps anything for the six destroyed tracks.
    - "70 definitions on action, in one frame": every earlier track is still fading out, and the
      controller destroys no track that is playing or fading out, so 70 tracks play or fade at once.
      That is more than the 64 that Roblox staff gave as the engine's limit of tracks playing on one
      `Animator`. Not known: whether the engine warns, refuses the later `Play` calls, or drops
      tracks, and whether the controller's tracks are usable afterwards.
15. **A kept track on a second rig.** "play walk", then "clear". In the Explorer, move the
    `AnimationController` that holds the dummy's `Animator` to a second rig with the same joint
    names, then "play walk" again: the second rig walks. `clear` keeps loaded tracks, so this is
    the kept track played on the rig its `Animator` is on now; VoxelMMO will rely on it.

## Still to measure

- Allocation per frame with the VMMO-45 method, on one body controller and on a body with one
  component controller.
- What a loaded, idle `AnimationTrack` costs, which decides whether 64 kept tracks per controller is
  the right cap.
- Whether `Ended` fires for a track whose `Animator` has left the DataModel. Until it does, such a
  track stays `fading` and is not played again; `clear` makes every track idle.
