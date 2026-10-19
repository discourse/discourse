---
title: Using the JS API
short_title: JS API
id: pluginapi
---

Discourse's JavaScript API allows themes and plugins to make extensive customizations to the user experience. The simplest way to use it is to create a new theme from the admin panel, click "Edit Code", and then head to the JS tab.

For file-based themes, the API can be used by creating a file in the `api-initializers` directory. For theme's that's `{theme}/javascripts/api-initializers/init-theme.gjs`, and for plugins, it's `{plugin}/assets/javascripts/discourse/api-initializers/init-plugin.js`. The content should be:

```gjs
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  // Your code here
});
```

All the available APIs are listed in the [`plugin-api.gjs` source code](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/plugin-api.gjs) in Discourse core, along with a short description and examples.

For a full tuturial, including examples of JS API usage, check out:

https://meta.discourse.org/t/theme-developer-tutorial-1-introduction/357796

## Loading the upload runtime

Upload setup remains synchronous. The upload runtime must be loaded before mounting components that call `UppyUpload.setup()` or `UppyComposerUpload.setup()`. Core upload interfaces use a render boundary:

```gjs
import UploadRuntime from "discourse/components/upload-runtime";
import CustomUploader from "./custom-uploader";

<template>
  <UploadRuntime>
    <CustomUploader />
  </UploadRuntime>
</template>
```

Put the boundary outside the uploader component when lifecycle hooks or subclass overrides expect an instance immediately after setup. For imperative code, load the runtime before calling setup:

```js
import loadUppy from "discourse/lib/load-uppy";

await loadUppy();
uploader.setup(fileInput);
// The instance is available immediately after setup returns.
```

The synchronous AMD shims for `@uppy/core`, `@uppy/aws-s3`, `@uppy/drop-target`, `@uppy/utils`, and `@uppy/xhr-upload` have been removed. Themes and plugins must replace direct package imports with the core loader. It returns `Uppy`, `BasePlugin`, `AwsS3`, `DropTarget`, and `XHRUpload`. Custom preprocessors can continue importing `UploadPreProcessorPlugin` from `discourse/lib/uppy-plugin-base` and registering classes during initialization.

Existing imports of the upload wrappers and uploader components remain available. External components that create their own uploaders must add the render boundary or preload explicitly. Setup throws a descriptive error if the runtime has not loaded. The render boundary handles load errors and offers a page refresh because browsers cache failed module imports; it does not mount its content after destruction.
