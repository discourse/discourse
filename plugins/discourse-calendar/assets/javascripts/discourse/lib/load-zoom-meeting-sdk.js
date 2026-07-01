import loadScript from "discourse/lib/load-script";

// The Zoom Meeting SDK is installed from npm (`@zoom/meetingsdk`) and served
// from the package's `dist` directory, which is symlinked into the plugin's
// `public/javascripts/zoom` folder. We load the prebuilt "global" bundles via
// script tags (rather than importing the package) because plugin assets are
// externalized at build time and cannot bundle npm dependencies.
//
// These bundles expect their peer dependencies to already exist as globals, so
// we load the vendor copies shipped alongside the SDK first.
const SDK_BASE_URL = "/plugins/discourse-calendar/javascripts/zoom";
const VENDOR_BASE_URL = `${SDK_BASE_URL}/lib/vendor`;
const SDK_VERSION = "6.2.0";
const SHARED_VENDOR_FILES = [
  "react.min.js",
  "react-dom.min.js",
  "react-redux.min.js",
  "redux.min.js",
  "redux-thunk.min.js",
];

let meetingSdkPromise;
let meetingSdkEmbeddedPromise;

function resolveGlobal(globalName) {
  const sdk = window[globalName];

  if (!sdk) {
    throw new Error(`${globalName} did not load`);
  }

  return sdk;
}

async function loadVendorDependencies(fileNames) {
  // Loaded sequentially because some vendor bundles read previously-defined
  // globals at evaluation time (e.g. react-dom expects React to exist).
  for (const fileName of fileNames) {
    await loadScript(`${VENDOR_BASE_URL}/${fileName}`);
  }
}

export async function loadZoomMeetingSdk() {
  meetingSdkPromise ??= loadVendorDependencies(SHARED_VENDOR_FILES)
    .then(() =>
      loadScript(`${SDK_BASE_URL}/zoom-meeting-${SDK_VERSION}.min.js`)
    )
    .then(() => resolveGlobal("ZoomMtg"));

  return meetingSdkPromise;
}

export async function loadZoomMeetingSdkEmbedded() {
  meetingSdkEmbeddedPromise ??= loadVendorDependencies(SHARED_VENDOR_FILES)
    .then(() => loadScript(`${SDK_BASE_URL}/zoom-meeting-embedded-ES5.min.js`))
    .then(() => resolveGlobal("ZoomMtgEmbedded"));

  return meetingSdkEmbeddedPromise;
}
