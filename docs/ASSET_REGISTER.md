# Asset register

Every shipped asset needs a row. No ripped commercial-game content. Founders approve every
license and the final in-game look. Keep source art outside the shipped `game/art` folder.

| Asset | Source URL | Creator | License | Receipt | Modifications | Permitted use |
|---|---|---|---|---|---|---|
| All current meshes | Generated in code (`game/art/art_kit.gd`) | DashPanda (code) | Proprietary | n/a | n/a | Prototype placeholder |
| All current audio | Synthesised at runtime (`game/audio/synth_audio.gd`) | DashPanda (code) | Proprietary | n/a | n/a | Prototype placeholder |
| UI font | Godot default theme font | Godot Engine contributors | MIT / OFL (verify for the shipped engine version) | n/a | none | Engine default |

Launch budget (page 7): 12 district blocks, 3 player looks, 2 police skins, 4 traffic looks,
one city palette. Triangle caps: hero vehicle 8–15k, ordinary prop 200–2k. Shared 1k atlases.
glTF/GLB with applied transforms, metres, a consistent forward axis (−Z) and named collision layers.
