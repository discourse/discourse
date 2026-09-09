The eleven review branches form one linear stack, with one operation added per commit. Original extraction heads and bases remain in [review-stack-manifest.json](review-stack-manifest.json). The final stack incorporates selective JPEG sampling and white SVG background fixes from cumulative source `c63ee831d4d2e332c466f1a272793eec94d9c22d`. These source identities are separate from benchmark snapshots; this table does not report test or CI status.

| Operation | Review branch | Base | Head |
| --- | --- | --- | --- |
| 01-animation | `tgxworld/vips-review-01-animation` | `0708de39bcebe79c8469dfd88cd568c8e71b42c7` | `345c05377b205be64d45a1ab13d909d231f725ff` |
| 02-svg-dimensions | `tgxworld/vips-review-02-svg-dimensions` | `345c05377b205be64d45a1ab13d909d231f725ff` | `60ee5446c33c68e5d9711ab717e6e8a29449dd32` |
| 03-svg-assets | `tgxworld/vips-review-03-svg-assets` | `60ee5446c33c68e5d9711ab717e6e8a29449dd32` | `3f82276023c2765e39a1a724dc62e71af0c126ac` |
| 04-og | `tgxworld/vips-review-04-og` | `3f82276023c2765e39a1a724dc62e71af0c126ac` | `9c2219b3bec399bc736fde3ddbec58f29df4420f` |
| 05-heif | `tgxworld/vips-review-05-heif` | `9c2219b3bec399bc736fde3ddbec58f29df4420f` | `4c106c0a96e78cb6d3b0547967e436e31fc198fa` |
| 06-ico | `tgxworld/vips-review-06-ico` | `4c106c0a96e78cb6d3b0547967e436e31fc198fa` | `7bd1abcfdeefa54ddc3cb1280f1e6710672da71b` |
| 07-jpeg | `tgxworld/vips-review-07-jpeg` | `7bd1abcfdeefa54ddc3cb1280f1e6710672da71b` | `83d09d9b023c095e0bd3afba560ab321f873eb91` |
| 08-orientation | `tgxworld/vips-review-08-orientation` | `83d09d9b023c095e0bd3afba560ab321f873eb91` | `f7ff3f7cf849e9173fff8704ab1600aa31866c62` |
| 09-downsize | `tgxworld/vips-review-09-downsize` | `f7ff3f7cf849e9173fff8704ab1600aa31866c62` | `d749cc4c4d1e92bc3fc0813de0bd306f51a6a7cb` |
| 10-resize | `tgxworld/vips-review-10-resize` | `d749cc4c4d1e92bc3fc0813de0bd306f51a6a7cb` | `110509b7f7f5807d467b7c93ba6a9159d2f45e5f` |
| 11-crop | `tgxworld/vips-review-11-crop` | `110509b7f7f5807d467b7c93ba6a9159d2f45e5f` | `e65d0762d8eda0bf3452e6f56ac298d0ad48ef3d` |

Branch 07 introduces JPEG sampling helpers, conversion coverage, and 4:2:2/4:4:0 fixtures; branch 08 adds orientation sampling coverage. Branches 09–11 introduce downsize, resize, and crop sampling/SVG coverage with each operation. Branch 10 retains the approved removal of the unused resize colors option. The orientation and geometry callers still use ImageMagick for quality estimation. Missing frozen-string directives remain a known lint gate pending approval; none were added during this rewrite.
