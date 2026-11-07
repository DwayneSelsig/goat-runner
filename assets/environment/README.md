# Environment artwork

Public SVGs are independent placeholders. The original artwork and extraction tool are private; the historical notes below describe those originals.


- `layers/` contains the supplied landscape layers and running-surface artwork.
- `source/` is a local, Git-ignored directory for the original artwork and full SVG sheets used by `tools/extract_environment.py`. These files are needed to regenerate the decor but are not needed to run or export the game. `background-farm.svg` is source art and is not loaded by the game.
- `props/` contains the extracted decor, grouped into vegetation, crops, buildings and fence modules. See [props/README.md](props/README.md) for regeneration details.
