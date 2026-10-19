---
title: Loading the upload runtime
short_title: Upload runtime
id: upload-runtime
---

The upload runtime loads on demand. `UppyUpload.setup()` and `UppyComposerUpload.setup()` throw until it has loaded.

Wrap the elements that call `setup()` in `UploadRuntime`, which renders them once the runtime is ready:

```gjs
<UploadRuntime>
  <input type="file" {{didInsert this.uppyUpload.setup}} />
</UploadRuntime>
```

Wrap only the upload controls, so the rest of the interface doesn't wait. Pass `@showSpinner={{false}}` when the wrapped controls are hidden. An uploader that calls `setup()` from its own lifecycle hooks must itself be rendered inside the boundary.

Outside templates, `await loadUppy()` from `discourse/lib/load-uppy` before calling `setup()`. It resolves to `{ Uppy, BasePlugin, AwsS3, DropTarget, XHRUpload }`, which replace the `@uppy/*` imports themes and plugins can no longer use. Composer upload preprocessors extend `UploadPreProcessorPlugin` from `discourse/lib/uppy-plugin-base` instead of `BasePlugin`.
