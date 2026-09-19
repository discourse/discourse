import getURL, { getURLWithCDN } from "discourse/lib/get-url";
import Site from "discourse/models/site";

// The heavyweight media assets (wasm engines, ML models, SDK bundles) ship in
// the discourse_voice_assets gem under stable filenames; the server mounts
// its vendor tree at a gem-version-stamped path and publishes that base here
// (versioned URLs bust the immutable /plugins/ caches on a gem bump, so
// nothing client-side changes when the gem does).
function basePath() {
  return Site.current().voice_assets_path;
}

// Assets ride the app-proxying CDN (getURLWithCDN's cdn), which serves the
// plugin's public dir. Absolutized against the page URL because the compiled
// chunk calling this may itself be served from a CDN origin, and a dynamic
// import() of a bare path would resolve against the chunk's origin, not the
// site's.
export function voiceAssetUrl(file) {
  return new URL(getURLWithCDN(`${basePath()}/${file}`), window.location).href;
}

// Same-origin variant: workers must load from the app origin (everything
// they fetch afterwards can still use voiceAssetUrl).
export function voiceAssetAppUrl(file) {
  return new URL(getURL(`${basePath()}/${file}`), window.location).href;
}
