The final measured ICO, JPEG, orientation, resize, and corrected SVG geometry operation methods align with their review branches. Downsize/crop raster snapshots differ only in the SVG loader arm; their separate corrected SVG snapshots match that arm too. This is a read-only source comparison, not a runtime test, benchmark rerun, or CI verdict.

The comparison reads the relevant facade method and worker operation, follows its named worker helpers, and checks shared client/sandbox support files. It excludes unrelated operations present in cumulative benchmark bundles. Exact means byte-identical extracted method text, including whitespace; reviewed formatting differences are called out separately. Detailed method lists and support checks are in [source-alignment-comparison.json](source-alignment-comparison.json).

| Branch | Exact head | Measured source scope | Alignment |
| --- | --- | --- | --- |
| 06 | `7bd1abcfdeefa54ddc3cb1280f1e6710672da71b` | `ico/benchmark` | Operation + loader blocking exact; IcoImage formatting differences only. |
| 07 | `83d09d9b023c095e0bd3afba560ab321f873eb91` | `jpeg/final-selective` | All 8 relevant worker methods and facade exact. |
| 08 | `f7ff3f7cf849e9173fff8704ab1600aa31866c62` | `orientation/final-selective` | All 5 relevant worker methods and facade exact in corrected 13-case bundle. |
| 09 | `d749cc4c4d1e92bc3fc0813de0bd306f51a6a7cb` | `downsize/benchmark; downsize/svg-white/benchmark` | 13/14 worker methods exact in raster bundle; all 14 exact in SVG rerun. |
| 10 | `110509b7f7f5807d467b7c93ba6a9159d2f45e5f` | `resize/benchmark` | All 15 relevant worker methods and facade exact. |
| 11 | `e65d0762d8eda0bf3452e6f56ac298d0ad48ef3d` | `crop/benchmark; crop/svg-white-{false,true}/benchmark` | 14/15 worker methods exact in raster bundle; all 15 exact in each SVG rerun. |

For downsize and crop, the only worker-method difference in the older raster bundles is `load_downsize_image`'s SVG arm: review code adds `.flatten(background: [255, 255, 255])`. Non-SVG loader arms remain exact. The separate white-background SVG bundles match the complete current method, including that arm. Their reports must remain separate source snapshots, not be presented as one run.

All compared facade methods match exactly. All bundles have byte-identical `client.rb`, `safe_exec.rb`, and instrumentation files. WorkerProcess is byte-identical except the isolated ICO bundle: the review branch also supplies Nokogiri/Racc load paths for inherited SVG operations. This changes the cumulative worker startup environment, so the ICO benchmark is not an identical-whole-process snapshot.

The ICO loader differs from branch 06 only in `%w`/`%i` array notation, line wrapping, and trailing-comma formatting; the complete diff was inspected. The JPEG cumulative bundle also contains the later keyword/page-selecting ICO API, while branch 07 retains positional last-frame loading. That ICO helper is not called by JPEG conversion and is excluded from JPEG alignment. Geometry branches 09–11 and their bundles have byte-identical ICO helper files.

Final orientation comparison used `/tmp/discourse-vips-orientation-01a0846e/public/discourse-task/orientation-benchmark` while its corrected 13-case report was being packaged as `orientation/final-selective`. The old `orientation/benchmark` artifact predates selective sampling and does not align: it lacks the sampling call and two helpers. Only the corrected bundle supports the alignment above.

Worker/facade method ordering differs because review commits introduce operations one at a time. No whole-worker hash identity is claimed. Staged sampling tests are scoped to available operations; branch 07 has three direct conversion examples, branches 08/09 omit invariant metadata loops, and branches 10/11 retain varying metadata modes. SVG tests reflect white-background semantics. Those spec changes are not benchmark runtime implementation changes. Branch 10 also contains the explicitly approved removal of legacy resize `colors` handling and its two obsolete tests; historical colors-option measurements are excluded.

This audit does not establish complete UploadCreator/OptimizedImage caller behavior, source-quality estimator equivalence, post-optimizer output equivalence, or final-head tests. Missing frozen-string directives and publication evidence links remain separate gates. Source and evidence files were not modified by this comparison.
