# mach1ne_policetape

Afspærringstape til FiveM (ESX). Politiet kan sætte tape op mellem flere punkter i verden og tage den ned igen. Tapen synkroniseres til alle spillere.

## Features

- **Tape mellem flere punkter**: Sæt A → B → C → ... (op til 8 punkter) i én afspærring.
- **Live preview**: Tapen vises, mens du sigter. Den bliver rød, hvis placeringen er ugyldig.
- **Følger terrænet**: Strækninger, der går gennem vægge, bakker eller objekter, afvises. Tapen løftes over jorden, hvor den hænger.
- **Blafrer i vinden**: Tapen bevæger sig let efter vindstyrken i spillet.
- **Tape-rulle i hånden**: Synkroniseret prop, mens tapen sættes op eller tages ned.
- **Blips på kortet**: Kun synlige for politiet.
- **Item-baseret med durability**: Kræver `policetape` fra ox_inventory. En rulle har `Config.RollLength` meter tape, og hver meter slider på rullen. Når rullen er tom, går itemet i stykker.
- **Job-låst**: Kun jobs i `Config.Jobs` (med minimum grade) kan bruge tapen.
- **Tag ned**: Stå ved et af punkterne og tryk `E`. Den nedtagne tape er brugt og gives ikke tilbage.
- **Server-validering**: Job, items, afstand og længde tjekkes på serveren.
- **Automatisk oprydning**: Tapen forsvinder efter en valgfri tid.
- **Performance**: Tapen tegnes kun tæt på spilleren med `DrawTexturedPoly`. Der bruges ingen entities.

## Krav

| Resource | Link |
| --- | --- |
| es_extended | https://github.com/esx-framework/esx_core |
| ox_lib | https://github.com/overextended/ox_lib |
| ox_inventory | https://github.com/overextended/ox_inventory |
| st_libs | https://github.com/Stausi/st_libs |

## Installation

1. Læg mappen `mach1ne_policetape` i din `resources`-mappe.
2. Tilføj itemet i `ox_inventory/data/items.lua`:

```lua
['policetape'] = {
    label = 'Afspærringstape',
    weight = 200,
    stack = false,
    close = true,
    consume = 0,
    description = 'Politiets afspærringstape',
    client = {
        export = 'mach1ne_policetape.useTape'
    },
},
```

Bemærk: `stack` skal være `false`, da hver rulle har sin egen durability i item-metadata. `consume = 0` sørger for, at ox_inventory ikke selv fjerner itemet ved brug.

3. Læg et billede med navnet `policetape.png` i `ox_inventory/web/images/`. Det er valgfrit.
4. Tilføj til `server.cfg` efter afhængighederne:

```cfg
ensure es_extended
ensure ox_lib
ensure ox_inventory
ensure st_libs
ensure mach1ne_policetape
```

5. Genstart serveren.

## Brug

Brug **Afspærringstape** fra inventaret.

| Tast | Handling |
| --- | --- |
| `E` | Sæt punkt |
| `Enter` | Færdig (min. 2 punkter) |
| `Backspace` | Fortryd sidste punkt / annuller |
| `Højreklik` | Annuller |

Sigter du på jorden, sættes punktet i hoftehøjde. Sigter du på en væg eller en pæl, sættes tapen direkte på den.

Du tager tapen ned ved at stå ved et af punkterne og trykke `E`.

## Konfiguration

Alt kan ændres i `config.lua`.

| Indstilling | Standard | Beskrivelse |
| --- | --- | --- |
| `Config.Item` | `'policetape'` | Item-navn i ox_inventory |
| `Config.Jobs` | `{ police = 0 }` | Jobs der må bruge tapen: `[job] = minimum grade` |
| `Config.ConsumeItem` | `true` | Brug tape fra rullens durability (`false` = uendelig tape) |
| `Config.RollLength` | `50.0` | Meter tape på en ny rulle (100% durability) |
| `Config.MaxTapesPerPlayer` | `10` | Max. aktive tapes pr. spiller (`0` = ingen grænse) |
| `Config.Lifetime` | `60` | Minutter før tapen fjernes automatisk (`0` = aldrig) |
| `Config.Tape.width` | `0.10` | Tapens højde i meter |
| `Config.Tape.minLength` / `maxLength` | `0.5` / `25.0` | Længde pr. strækning |
| `Config.Tape.maxPoints` | `8` | Max. punkter i én tape |
| `Config.Tape.sagPerMeter` / `maxSag` | `0.008` / `0.20` | Hvor meget tapen hænger |
| `Config.Tape.renderDistance` | `80.0` | Hvor langt væk tapen tegnes |
| `Config.Terrain.blockThroughWalls` | `true` | Afvis strækninger gennem vægge og terræn |
| `Config.Terrain.collisionFlags` | `1 \| 16` | 1 = verden, 16 = objekter |
| `Config.Wind.enabled` | `true` | Blafren i vinden |
| `Config.Blip.enabled` | `true` | Blips for politiet |
| `Config.Prop.enabled` | `true` | Tape-rulle i hånden |
| `Config.Prop.pos` / `rot` | | Justér proppens placering i hånden |
| `Config.Place.maxDistance` | `5.0` | Hvor langt væk et punkt må sættes |
| `Config.Place.groundHeight` | `1.0` | Højde over jorden ved sigte på gulvet |
| `Config.Place.duration` | `2500` | Progressbar ved opsætning (ms) |
| `Config.Remove.duration` | `2000` | Progressbar ved nedtagning (ms) |

### Egen texture

Texturen ligger i `stream/prop_police_tape.ytd` (texture `POLICE_TAPE`, 994×29). Hvis du vil bruge din egen, så ret `Config.Texture.dict`, `name` og `aspect` (bredde / højde).


## Credits

Lavet af **TheMach1neDK**.
