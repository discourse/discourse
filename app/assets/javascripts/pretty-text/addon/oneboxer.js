import {
  failedCache,
  lookupCache,
  normalize,
  resetFailedCache,
  resetLocalCache,
  setFailedCache,
  setLocalCache,
} from "pretty-text/oneboxer-cache";
import domFromString from "discourse/lib/dom-from-string";
import discourseLater from "discourse/lib/later";

let timeout;
const loadingQueue = [];

export const LOADING_ONEBOX_CSS_CLASS = "loading-onebox";

export function resetCache() {
  loadingQueue.clear();
  resetLocalCache();
  resetFailedCache();
}

function resolveSize(img) {
  img.classList.add("size-resolved");

  if (img.width > 0 && img.width === img.height) {
    img.classList.add("onebox-avatar");
  }
}

// Detect square images and apply smaller onebox-avatar class
function applySquareGenericOnebox(elem) {
  if (!elem.classList.contains("allowlistedgeneric")) {
    return;
  }

  let img = elem.querySelector(".onebox-body img.thumbnail");

  // already resolved... skip
  if (!img || img.classList.contains("size-resolved")) {
    return;
  }

  if (img.complete) {
    resolveSize(img);
  } else {
    img.addEventListener("load", _handleLoadingOneboxImages);
  }
}

function _handleLoadingOneboxImages() {
  resolveSize(this);
  this.removeEventListener("load", _handleLoadingOneboxImages);
}

function loadNext(ajax) {
  if (loadingQueue.length === 0) {
    timeout = null;
    return;
  }

  let timeoutMs = 150;
  let removeLoading = true;
  const { url, refresh, elem, categoryId, topicId } = loadingQueue.shift();

  // Retrieve the onebox
  return ajax("/onebox", {
    dataType: "html",
    data: {
      url,
      refresh,
      category_id: categoryId,
      topic_id: topicId,
    },
  })
    .then(
      (template) => {
        const node = domFromString(template)[0];
        setLocalCache(normalize(url), node);
        elem.replaceWith(node);
        applySquareGenericOnebox(node);
      },
      (result) => {
        if (result?.jqXHR?.status === 429) {
          timeoutMs = 2000;
          removeLoading = false;
          loadingQueue.unshift({ url, refresh, elem, categoryId, topicId });
        } else {
          setFailedCache(normalize(url), true);
        }
      }
    )
    .finally(() => {
      timeout = discourseLater(() => loadNext(ajax), timeoutMs);
      if (removeLoading) {
        elem.classList.remove(LOADING_ONEBOX_CSS_CLASS);
        elem.dataset.oneboxLoaded = "";
      }
    });
}

// Perform a lookup of a onebox based an anchor element.
// It will insert a loading indicator and remove it when the loading is complete or fails.
export function load({
  elem,
  ajax,
  topicId,
  categoryId,
  refresh = true,
  offline = false,
  synchronous = false,
}) {
  // If the onebox has loaded or is loading, return

  if (elem.dataset.oneboxLoaded) {
    return;
  }

  if (elem.classList.contains(LOADING_ONEBOX_CSS_CLASS)) {
    return;
  }

  const url = elem.href;

  // Unless we're forcing a refresh...
  if (!refresh) {
    // If we have it in our cache, return it.
    const cached = lookupCache(url);
    if (cached) {
      return cached;
    }

    // If the request failed, don't do anything
    const failed = failedCache[normalize(url)];
    if (failed) {
      return;
    }

    if (offline) {
      return;
    }
  }

  // Add the loading CSS class
  elem.classList.add(LOADING_ONEBOX_CSS_CLASS);

  // Add to the loading queue
  loadingQueue.push({ url, refresh, elem, categoryId, topicId });

  // Load next url in queue
  if (synchronous) {
    return loadNext(ajax);
  } else {
    timeout = timeout || discourseLater(() => loadNext(ajax), 150);
  }
}
