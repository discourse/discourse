let _started = false;
let cache = {};
let transitionCount = 0;

export function setTransient(key, data, count) {
  cache[key] = { data, target: transitionCount + count };
}

export function getTransient(key) {
  return cache[key];
}

export function resetPageTracking() {
  _started = false;
  transitionCount = 0;
  cache = {};
}

export function startPageTracking(router, appEvents) {
  if (_started) {
    return;
  }
  router.on("routeDidChange", transition => {
    // we ocassionally prevent tracking of replaced pages when only query params changed
    // eg: google analytics
    const replacedOnlyQueryParams =
      transition.urlMethod === "replace" && transition.queryParamsOnly;

    router.send("refreshTitle");
    const url = Discourse.getURL(router.get("url"));

    // Refreshing the title is debounced, so we need to trigger this in the
    // next runloop to have the correct title.
    Ember.run.next(() => {
      let title = Discourse.get("_docTitle");

      appEvents.trigger("page:changed", {
        url,
        title,
        currentRouteName: router.currentRouteName,
        replacedOnlyQueryParams
      });
    });

    transitionCount++;
    Object.keys(cache).forEach(k => {
      const v = cache[k];
      if (v && v.target && v.target < transitionCount) {
        delete cache[k];
      }
    });
  });

  _started = true;
}

const _gtmPageChangedCallbacks = [];

export function addGTMPageChangedCallback(callback) {
  _gtmPageChangedCallbacks.push(callback);
}

export function googleTagManagerPageChanged(data) {
  let gtmData = {
    event: "virtualPageView",
    page: {
      title: data.title,
      url: data.url
    }
  };

  _gtmPageChangedCallbacks.forEach(callback => callback(gtmData));

  window.dataLayer.push(gtmData);
}
