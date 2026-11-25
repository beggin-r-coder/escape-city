# Asset register

Every shipped asset needs a row. No ripped commercial-game content. Founders approve every
license and the final in-game look. Keep source art outside the shipped `game/art` folder.

| Asset | Source URL | Creator | License | Receipt | Modifications | Permitted use |
|---|---|---|---|---|---|---|
| Cars, police, traffic, cone, crate, crash debris (`game/art/kenney/cars/`) | https://kenney.nl/assets/car-kit (Car Kit 3.1) | Kenney (www.kenney.nl) | CC0 1.0 (`License.txt` in folder) | Free download, supplied by founders | Selected GLBs only; garage icons copied from kit previews | Commercial use allowed; credit appreciated, not required |
| Buildings, skyscrapers, parasols (`game/art/kenney/city/`) | https://kenney.nl/assets/city-kit-commercial (2.1) | Kenney | CC0 1.0 | Free download, supplied by founders | Selected GLBs only | Commercial use allowed |
| Road tiles, junctions, crossings, street/traffic lights, construction props (`game/art/kenney/roads/`) | https://kenney.nl/assets/city-kit-roads | Kenney | CC0 1.0 | Free download, supplied by founders | Selected GLBs only; tiles flattened in-engine | Commercial use allowed |
| Trees, block ground, skid marks, coins | Generated in code (`game/art/art_kit.gd`, `skid_marks.gd`) | DashPanda (code) | Proprietary | n/a | n/a | Placeholder until replaced |
| All current audio | Synthesised at runtime (`game/audio/synth_audio.gd`) | DashPanda (code) | Proprietary | n/a | n/a | Prototype placeholder |
| UI font | Godot default theme font | Godot Engine contributors | MIT / OFL (verify for the shipped engine version) | n/a | none | Engine default |

Launch budget (page 7): 12 district blocks, 3 player looks, 2 police skins, 4 traffic looks,
one city palette. Triangle caps: hero vehicle 8–15k, ordinary prop 200–2k. Shared 1k atlases.
glTF/GLB with applied transforms, metres, a consistent forward axis (−Z) and named collision layers.
