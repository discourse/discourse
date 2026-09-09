The eleven review branches form one linear stack, with one operation added per parent-branch diff. Original extraction heads and bases remain in [review-stack-manifest.json](review-stack-manifest.json). The final stack incorporates selective JPEG sampling and white SVG background fixes from cumulative source `c63ee831d4d2e332c466f1a272793eec94d9c22d`. These source identities are separate from benchmark snapshots; this table does not report test or CI status.

| Operation | Review branch | Base | Head |
| --- | --- | --- | --- |
| 01-animation | `tgxworld/vips-review-01-animation` | `0708de39bcebe79c8469dfd88cd568c8e71b42c7` | `345c05377b205be64d45a1ab13d909d231f725ff` |
| 02-svg-dimensions | `tgxworld/vips-review-02-svg-dimensions` | `345c05377b205be64d45a1ab13d909d231f725ff` | `60ee5446c33c68e5d9711ab717e6e8a29449dd32` |
| 03-svg-assets | `tgxworld/vips-review-03-svg-assets` | `60ee5446c33c68e5d9711ab717e6e8a29449dd32` | `3f82276023c2765e39a1a724dc62e71af0c126ac` |
| 04-og | `tgxworld/vips-review-04-og` | `3f82276023c2765e39a1a724dc62e71af0c126ac` | `9c2219b3bec399bc736fde3ddbec58f29df4420f` |
| 05-heif | `tgxworld/vips-review-05-heif` | `9c2219b3bec399bc736fde3ddbec58f29df4420f` | `4c106c0a96e78cb6d3b0547967e436e31fc198fa` |
| 06-ico | `tgxworld/vips-review-06-ico` | `4c106c0a96e78cb6d3b0547967e436e31fc198fa` | `a29087e9804520698437ca32cbfd7888749d96a4` |
| 07-jpeg | `tgxworld/vips-review-07-jpeg` | `a29087e9804520698437ca32cbfd7888749d96a4` | `0a96aa3f57a23c177b9cc5bd05de268a7d3a83df` |
| 08-orientation | `tgxworld/vips-review-08-orientation` | `0a96aa3f57a23c177b9cc5bd05de268a7d3a83df` | `7548d192b0fc01607b0df1b7abf6abb768a15d51` |
| 09-downsize | `tgxworld/vips-review-09-downsize` | `7548d192b0fc01607b0df1b7abf6abb768a15d51` | `5a9c7942712d9338e2cdd5fbdec4399ca9a4b4ea` |
| 10-resize | `tgxworld/vips-review-10-resize` | `5a9c7942712d9338e2cdd5fbdec4399ca9a4b4ea` | `d88b4e83bd92d15c1a76131a46eb9761df501882` |
| 11-crop | `tgxworld/vips-review-11-crop` | `d88b4e83bd92d15c1a76131a46eb9761df501882` | `381562e9e9b8502a9847dc4d08f49e8dc97f0979` |

Branch 07 introduces JPEG sampling helpers, conversion coverage, and 4:2:2/4:4:0 fixtures; branch 08 adds orientation sampling coverage. Branches 09–11 introduce downsize, resize, and crop sampling/SVG coverage with each operation. Branch 10 retains the approved removal of the unused resize colors option. The orientation and geometry callers still use ImageMagick for quality estimation. The required frozen-string directives were approved and added in their introduction commits; the five-file root lint check passed.

The GIF signature lint fix is an ordinary commit in branch07, merged through branches08–11. Published history remains intact; the current head may be a merge commit whose first parent is its prior published head.
