import loadScript from "discourse/lib/load-script";

// The Zoom Meeting SDK is hotlinked from Zoom's CDN rather than bundled, so it
// stays out of Discourse's build and Zoom serves matching wasm/AV assets from
// the same origin. Bump this to adopt a newer SDK release.
// https://developers.zoom.us/docs/meeting-sdk/web/get-started/
const ZOOM_SDK_VERSION = "6.2.0";
const CDN = "https://source.zoom.us";

// Shared by both views; React must precede ReactDOM, and Redux precede its thunk.
const DEPENDENCIES = ["react", "react-dom", "redux", "redux-thunk", "lodash"];

async function loadDependencies() {
  for (const dep of DEPENDENCIES) {
    await loadScript(`${CDN}/${ZOOM_SDK_VERSION}/lib/vendor/${dep}.min.js`);
  }
}

// Client View (`ZoomMtg`) - renders the full Zoom client UI.
export async function loadZoomMeetingSdk() {
  await loadDependencies();
  await loadScript(`${CDN}/zoom-meeting-${ZOOM_SDK_VERSION}.min.js`);
  return window.ZoomMtg;
}

// Component View (`ZoomMtgEmbedded`) - embeds Zoom inside a container element.
export async function loadZoomMeetingSdkEmbedded() {
  await loadDependencies();
  await loadScript(`${CDN}/zoom-meeting-embedded-${ZOOM_SDK_VERSION}.min.js`);
  return window.ZoomMtgEmbedded;
}
