The final measured ICO, JPEG, orientation, resize, and corrected SVG geometry operation methods align with their review branches. Downsize/crop raster snapshots differ only in the SVG loader arm; their separate corrected SVG snapshots match that arm too. This is a read-only source comparison, not a runtime test, benchmark rerun, or CI verdict.

The comparison reads the relevant facade method and worker operation, follows its named worker helpers, and checks shared client/sandbox support files. It excludes unrelated operations present in cumulative benchmark bundles. Exact means byte-identical extracted method text, including whitespace; reviewed formatting differences are called out separately. Detailed method lists and support checks are in [source-alignment-comparison.json](source-alignment-comparison.json).

| Branch | Exact head | Measured source scope | Alignment |
| --- | --- | --- | --- |
| 06 | `a29087e9804520698437ca32cbfd7888749d96a4` | `ico/benchmark` | Operation + loader blocking exact; IcoImage formatting differences only. |
| 07 | `04940386277b10722d9dc296fa9a98a851ccda6f` | `jpeg/final-selective` | All 8 relevant worker methods and facade exact. |
| 08 | `871a32ddf21e33322c6fdab41afe89d766d9dd74` | `orientation/final-selective` | All 5 relevant worker methods and facade exact in corrected 13-case bundle. |
| 09 | `8eebe47e5c1c630f2ccd77afbc58a5900f6f92b8` | `downsize/benchmark; downsize/svg-white/benchmark` | 13/14 worker methods exact in raster bundle; all 14 exact in SVG rerun. |
| 10 | `79abe3aae19814a2ce8e63a586fa9682567a6a0e` | `resize/benchmark` | All 15 relevant worker methods and facade exact. |
| 11 | `a72c194e07357fddd533eec94dc52a9add4f8201` | `crop/benchmark; crop/svg-white-{false,true}/benchmark` | 14/15 worker methods exact in raster bundle; all 15 exact in each SVG rerun. |

For downsize and crop, the only worker-method difference in the older raster bundles is `load_downsize_image`'s SVG arm: review code adds `.flatten(background: [255, 255, 255])`. Non-SVG loader arms remain exact. The separate white-background SVG bundles match the complete current method, including that arm. Their reports must remain separate source snapshots, not be presented as one run.

All compared facade methods match exactly. All bundles have byte-identical `client.rb`, `safe_exec.rb`, and instrumentation files. WorkerProcess is byte-identical except the isolated ICO bundle: the review branch also supplies Nokogiri/Racc load paths for inherited SVG operations. This changes the cumulative worker startup environment, so the ICO benchmark is not an identical-whole-process snapshot.

The ICO loader differs from branch 06 only in `%w`/`%i` array notation, line wrapping, and trailing-comma formatting; the complete diff was inspected. The JPEG cumulative bundle also contains the later keyword/page-selecting ICO API, while branch 07 retains positional last-frame loading. That ICO helper is not called by JPEG conversion and is excluded from JPEG alignment. Geometry branches 09–11 and their bundles have byte-identical ICO helper files.

Final orientation comparison used `/tmp/discourse-vips-orientation-01a0846e/public/discourse-task/orientation-benchmark` while its corrected 13-case report was being packaged as `orientation/final-selective`. The old `orientation/benchmark` artifact predates selective sampling and does not align: it lacks the sampling call and two helpers. Only the corrected bundle supports the alignment above.

Worker/facade method ordering differs because review commits introduce operations one at a time. No whole-worker hash identity is claimed. Staged sampling tests are scoped to available operations; branch 07 has three direct conversion examples, branches 08/09 omit invariant metadata loops, and branches 10/11 retain varying metadata modes. SVG tests reflect white-background semantics. Those spec changes are not benchmark runtime implementation changes. Branch 10 also contains the explicitly approved removal of legacy resize `colors` handling and its two obsolete tests; historical colors-option measurements are excluded.

This audit does not establish complete UploadCreator/OptimizedImage caller behavior, source-quality estimator equivalence, post-optimizer output equivalence, or final-head tests. Required frozen-string directives have now been approved and added; publication evidence links and final-head validation remain separate gates. Source and evidence files were not modified by this comparison.

The review heads above include the approved directives from `fa39599e6aa0050750f1014228b374b7f4f74c4d`. Compared with the previous aligned heads, every changed file differs only by the two-line frozen-string header. Operation method bodies remain byte-identical. Full ICO helper-file identity against geometry benchmarks now differs by that header alone; freezing can affect runtime strings, so this source comparison does not replace the scheduled behavioral tests. Benchmark source files remain untouched.
