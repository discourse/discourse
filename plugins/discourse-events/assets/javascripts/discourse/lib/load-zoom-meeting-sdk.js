import loadScript from "discourse/lib/load-script";

// The Zoom Meeting SDK is hotlinked from Zoom's CDN rather than bundled, so it
// stays out of Discourse's build and Zoom serves matching wasm/AV assets from
// the same origin. Bump this to adopt a newer SDK release.
// https://developers.zoom.us/docs/meeting-sdk/web/get-started/
//
// The page the meeting is embedded in loads the SDK for itself and pins the
// same version in `LivestreamController::ZOOM_SDK_VERSION`, which a bump here
// has to carry to.
const ZOOM_SDK_VERSION = "6.2.0";
const CDN = "https://source.zoom.us";

// React must precede ReactDOM, and Redux precede its thunk.
const DEPENDENCIES = ["react", "react-dom", "redux", "redux-thunk", "lodash"];

async function loadDependencies() {
  for (const dep of DEPENDENCIES) {
    await loadScript(`${CDN}/${ZOOM_SDK_VERSION}/lib/vendor/${dep}.min.js`);
  }
}

// Component View (`ZoomMtgEmbedded`) - embeds Zoom inside a container element.
export async function loadZoomMeetingSdkEmbedded() {
  await loadDependencies();
  await loadScript(`${CDN}/zoom-meeting-embedded-${ZOOM_SDK_VERSION}.min.js`);
  return window.ZoomMtgEmbedded;
}
