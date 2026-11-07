# Environment decor

Generated from the supplied `../source/enviroment_props.svg` and `../source/enviroment_props-farm.svg`. The Git-ignored source sheets must be available locally to rebuild from the repository root:

```sh
python tools/extract_environment.py
```

The extractor records group IDs, source sheets and crop bounds, retains ancestor transforms and SVG definitions, and preserves both source files. Width and height use a maximum 512-pixel import resolution; the original vector geometry remains in each viewBox. Change the extractor when adjusting selections or crops, then regenerate these files. Generated props are grouped into `vegetation`, `crops`, `buildings` and `fence`; `picket_open.svg` is the perspective open gate leaf from farm group `g19296`.

The landscape uses trees, fruit trees, crops, flowers and occasional farm buildings as visual decor. The foreground additionally combines the extracted lettuce, individual sunflower and corn plants, grass blade and two sprouts with existing crops and flowers. Fence, gate and post modules keep their natural proportions. None of these assets adds collisions or gameplay interactions.
