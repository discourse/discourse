import { waitForPromise } from "@ember/test-waiters";

let runtime;
let loading;

export function getUppy() {
  if (!runtime) {
    throw new Error(
      "Load the upload runtime with loadUppy() before calling setup()."
    );
  }
  return runtime;
}

export function isUppyLoaded() {
  return Boolean(runtime);
}

export default function loadUppy() {
  loading ??= waitForPromise(
    import("discourse/static/uppy").then((loaded) => {
      runtime = loaded;
      return runtime;
    })
  );
  return loading;
}
