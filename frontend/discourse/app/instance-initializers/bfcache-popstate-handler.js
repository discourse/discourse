import PreloadStore from "discourse/lib/preload-store";

let suppressNextPopstate = false;

function onPageShow(event) {
  if (event.persisted) {
    suppressNextPopstate = true;
  }
}

function onPopstate(event) {
  if (suppressNextPopstate) {
    suppressNextPopstate = false;
    event.stopImmediatePropagation();
  }
}

export default {
  initialize() {
    const siteSettings = PreloadStore.get("siteSettings");
    if (!siteSettings?.cache_control_bfcache_compatibility) {
      return;
    }

    window.addEventListener("pageshow", onPageShow);
    // Use capture phase to intercept before Ember's HistoryLocation listener
    window.addEventListener("popstate", onPopstate, true);
  },

  teardown() {
    window.removeEventListener("pageshow", onPageShow);
    window.removeEventListener("popstate", onPopstate, true);
  },
};
