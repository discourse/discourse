Final selective source snapshot: 2ba8357019543403265a8b4cd24c906815484efe

The case manifest now expects EXIF orientation 1 for both unchanged uncommon-sampling fixtures. Their actual IFD0 orientation tags contain 1, not an absent value. The exact metadata assertion remains intact, and the input bytes and production worker are unchanged.

The failed first run and its old manifest are preserved in history/failed-selective-orientation-expectation. Before rerunning on the production server, copy its existing final-selective.json and outputs-final-selective into that history directory; the local correction preserved the coordinator log and eleven sample records, but those remote artifacts were not available locally.

Upload corrected cases.json and source-manifest.json plus the new history directory. Run all thirteen cases afresh, serialized as the same unprivileged discourse user in the same image:

```sh
RESULT_PATH=final-selective-corrected.json bundle exec ruby boot.rb
```

The harness does not resume partial runs. New outputs still go to outputs-final-selective, so archive the failed outputs first. Source and harness checksums are checked before execution. Do not run prepare_bundle.py: it is the historical initial builder, not the current full-source snapshot refresher.
