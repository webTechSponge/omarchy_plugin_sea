# Brand artwork

Generated using the built-in image generation tool on 2026-09-05.

- `wordmark-dark-v1.png`: horizontal logo and Omarchy Plugin Sea wordmark.
- `icon-dark-v1.png`: matching standalone wave-and-plug icon.

The current transparent branding is version 4: `wordmark-pluginsea-v4.png` and `icon-pluginsea-v4.png`, used in the app header and detail pages respectively. The graphical name joins **PluginSea**, with cream **PluginS** and turquoise **ea** sharing the S. Earlier versions remain as design history. Exact version 3 prompts are in [pluginsea-v3-notes.md](pluginsea-v3-notes.md).

These are RGBA PNG assets with a genuinely transparent background, a thin navy contour and a soft edge shadow for light/dark theme legibility. Version 4 is derived locally from the approved version 3 artwork without changing its shapes or lettering. The opaque version 3 originals are retained. The lettering is artwork; the interface retains the accessible plain-text name Omarchy Plugin Sea. The development installer copies only the approved pair into the runtime plugin.

## Prompts

### Initial direction

Use case: logo-brand. Create a polished original logo and graphical wordmark for the Linux desktop app "Omarchy Plugin Sea". Deliver a finished horizontal brand lockup on a genuinely transparent background, wide composition approximately 2:1, high resolution. Left: one strong compact emblem, a curling ocean wave whose crest seamlessly becomes an electric plug with two clear prongs; the cable forms the sweeping lower curve of the wave, clever integrated negative space, recognizable simple silhouette at icon size. Right: beautifully crafted custom geometric typography, "OMARCHY" as a small widely tracked upper line, "Plugin Sea" as the dominant expressive lower line, exact spelling. Make the wave-and-plug symbol and lettering feel like a single confident contemporary open-source identity, playful but precise. Flat vector-like shapes, crisp smooth edges, ocean turquoise and electric blue accents, pale warm-white lettering for a dark desktop. Subtle wave movement in the lettering, restrained and readable; no generic tech circuitry, no literal wall outlet, no extra objects, no slogan, no mockup, no shadows, no bevels, no watermark, no background rectangle. Generous safe margins. This is final usable logo artwork, not a presentation board.

### Cleanup

Edit this logo into clean production artwork. Preserve the exact composition, wave with electric plug, ocean cyan/blue colors, and correctly spelled OMARCHY / Plugin Sea lettering. Remove ALL grain, speckling, white spray behind or between the letters, ragged pixels, distressing, stray marks, and texture. The space outside and between every shape must be genuinely transparent with clean smooth antialiased contours. Use solid fills and a few crisp color bands, no noisy edges. Keep the bold expressive lettering, readable clean warm-white text and integrated wave underline. Do not add anything. Transparent PNG, same wide composition and generous margins.

### Final wordmark

Edit this exact logo artwork. Replace the entire gray and white checkerboard background with a perfectly uniform solid dark midnight navy background #1b1d2b. All gaps between letters, inside letter counters, inside the wave curl, and surrounding the artwork must use the SAME solid navy. Preserve the wave-and-electric-plug emblem, smooth cyan/electric-blue curves, cream-white exact lettering "OMARCHY" and "Plugin Sea", placement and proportions. Remove thin gray outlines on cream letters so lettering is clean and bold on navy. No checkerboard, no transparency, no texture, no speckles, no glow, no shadows. Produce a crisp finished horizontal app brand banner.

### Matching icon

Use the supplied brand logo as a style reference to create its matching standalone square app icon. ONLY the curling cyan/electric-blue ocean wave merging with a two-prong electric plug; remove all lettering and the long underline, make wave tail curl back into a compact near-circular emblem. Simplify to broad bold shapes with minimal droplets, clean silhouette, recognizable at small size. Retain bright turquoise, blue and white foam and prongs. Center the large emblem with 12% safe margins on uniform dark midnight navy. Square 1024x1024 composition. No words, no letters, no watermark, no checkerboard, no presentation layout. Finished app icon.

## Reproduce transparent version 4

The user approved local image processing after generated exports baked in a checkerboard. No generated checkerboard asset is shipped. The offline Qt tool removes the near-navy matte, unmattes partial edge pixels and adds a four-source-pixel contour with a gently blurred shadow. It is artwork preparation only; the app gains no dependency or shader.

```bash
mise exec -- bash -c 'g++ -std=c++17 assets/branding/tools/transparent.cpp -o /tmp/sea-brand $(pkg-config --cflags --libs Qt6Gui)'
/tmp/sea-brand assets/branding/wordmark-pluginsea-v3.png assets/branding/wordmark-pluginsea-v4.png
/tmp/sea-brand assets/branding/icon-pluginsea-v3.png assets/branding/icon-pluginsea-v4.png
```

Pixels outside the artwork and edge shadow have alpha zero; partially transparent pixels preserve smooth edges. Both assets were inspected on dark navy, white and pale blue backgrounds.
