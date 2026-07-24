# mcpe-odin

Unofficial Odin ports of go-raknet, gophertunnel, and Dragonfly for Minecraft:
Bedrock Edition.

Current implementation target:

- go-raknet `0d1fd09e2cf6d50dbc7c0764731109196ed9e248`
- gophertunnel `0a2ecd5633ea1466ff97f6d4718df66ec14d054f`
- Dragonfly `11e6c74c87f1e775ae28856117f075302c4fa814`
- Minecraft `1.26.30`, protocol `1001`
- Odin `dev-2026-07a`
- Linux x86-64

This repository is under active construction. Stable release tags are created
only after their corresponding compatibility gate passes. Missing features are
tracked explicitly in `api-map.toml`; package presence does not imply parity.

## Commands

```sh
./tools/odinw test
./tools/odinw check
./tools/odinw build dragonfly
./tools/odinw run dragonfly
```

Use packages from another Odin project:

```sh
odin build . -collection:mcpe=/path/to/mcpe-odin/packages
```

```odin
import raknet "mcpe:raknet"
```

## Compatibility policy

Upstream behaviour is authoritative, including quirks. Public Odin APIs keep
upstream concepts and names recognizable while using Odin procedures, result
tuples, explicit ownership, and context allocators. See `compatibility.md`.

This project is not affiliated with Mojang Studios, Microsoft, Sandertv, or
Dragonfly contributors.

