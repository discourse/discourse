Current published stack source alignment

Integration `81f71327e66f0db320939fc8def0826e2e4ea1e0` and all twelve operation worktrees were clean at this read-only audit. Every published head is an ancestor of the following head. This compares source, not runtime behavior or CI.

| PR | Operation | Head |
| --- | --- | --- |
| 43453 | animation | `345c05377b205be64d45a1ab13d909d231f725ff` |
| 43454 | svg-dimensions | `60ee5446c33c68e5d9711ab717e6e8a29449dd32` |
| 43455 | svg-assets | `3f82276023c2765e39a1a724dc62e71af0c126ac` |
| 43456 | og | `9c2219b3bec399bc736fde3ddbec58f29df4420f` |
| 43457 | heif | `4c106c0a96e78cb6d3b0547967e436e31fc198fa` |
| 43462 | ico | `a29087e9804520698437ca32cbfd7888749d96a4` |
| 43463 | jpeg | `0a96aa3f57a23c177b9cc5bd05de268a7d3a83df` |
| 43464 | orientation | `7548d192b0fc01607b0df1b7abf6abb768a15d51` |
| 43465 | downsize | `fab2dead96404c8c415ca8732d04b581e3e5ca8c` |
| 43466 | resize | `61227f084ac0ac0b6857ab2a6b7979f605080f3c` |
| 43467 | crop | `938adc3edff793fff465e9bce13bdd8219faaccd` |
| 43478 | quality | `19727de95fd7096f4cc32a7b8a9be1e73202ac2d` |

PR12 differs from integration in only four files: facade method order (all 16 method bodies identical); worker method and dispatch order plus an equivalent expanded GIF guard (same 55 methods); order of 12 identical facade spec groups; and expansion of the rotated-image parameter loop into five operation-specific examples with the same inputs, calls and assertions. No material source mismatch was found.

Earlier source-alignment artifacts retain historical benchmark-source comparisons and older heads. The first-frame WebP supplement records the later geometry selection fix separately. All three reviewers accepted the cumulative integration source on pass three; this is not twelve independent PR approvals. The user-approved crop depth fix was accepted by all three reviewers on pass three. The complete facade and OptimizedImage_vips specs passed 90 examples.
