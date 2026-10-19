import { waitForPromise } from "@ember/test-waiters";
import { i18n } from "discourse-i18n";

const importRuntime = () => import("discourse/static/uppy");

let importer = importRuntime;
let runtime;
let loading;
let failureReported = false;

export function getUppy() {
  if (!runtime) {
    throw new Error("The upload runtime has not loaded yet.");
  }
  return runtime;
}

/**
 * Loads the upload runtime. Themes and plugins use it in place of the
 * `@uppy/*` packages, which they cannot import.
 *
 * @returns {Promise<{ Uppy, BasePlugin, AwsS3, DropTarget, XHRUpload }>}
 */
export default function loadUppy() {
  loading ??= waitForPromise(
    importer().then((loaded) => {
      runtime = loaded;
      return runtime;
    })
  );
  return loading;
}

/**
 * Runs `callback` with the upload runtime: synchronously when it has already
 * loaded, otherwise once it loads.
 *
 * @param {(runtime: object) => void} callback
 * @returns {Promise<boolean>} whether the runtime is available
 */
export function withUppy(callback) {
  if (runtime) {
    callback(runtime);
    return Promise.resolve(true);
  }

  return waitForPromise(
    loadUppy().then(
      (loaded) => {
        callback(loaded);
        return true;
      },
      () => false
    )
  );
}

// Every uploader shares the failed import, so one notice covers the page.
export function reportUppyLoadFailure(dialog) {
  if (failureReported) {
    return;
  }
  failureReported = true;
  dialog.alert(i18n("upload_selector.runtime_load_failed"));
}

export function resetUppyForTesting({ importer: testImporter } = {}) {
  importer = testImporter ?? importRuntime;
  runtime = undefined;
  loading = undefined;
  failureReported = false;
}
