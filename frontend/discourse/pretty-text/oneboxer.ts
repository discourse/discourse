import type { Timer } from "@ember/runloop";
import type { ajax as discourseAjax, AjaxError } from "discourse/lib/ajax";
import domFromString from "discourse/lib/dom-from-string";
import discourseLater from "discourse/lib/later";
import {
  failedCache,
  lookupCache,
  normalize,
  resetFailedCache,
  resetLocalCache,
  setFailedCache,
  setLocalCache,
} from "./oneboxer-cache.ts";

/** A link waiting for its onebox. */
interface QueuedOnebox {
  url: string;
  refresh: boolean;
  elem: HTMLAnchorElement;
  categoryId?: number;
  topicId?: number;
  onResolve?: (html: string | null) => void;
}

let timeout: Timer | null | undefined;
const loadingQueue: QueuedOnebox[] = [];

export const LOADING_ONEBOX_CSS_CLASS = "loading-onebox";

export function resetCache() {
  loadingQueue.length = 0;
  resetLocalCache();
  resetFailedCache();
}

function resolveSize(img: HTMLImageElement) {
  img.classList.add("size-resolved");

  if (img.width > 0 && img.width === img.height) {
    img.classList.add("onebox-avatar");
  }
}

// Detect square images and apply smaller onebox-avatar class
function applySquareGenericOnebox(elem: Element) {
  if (!elem.classList.contains("allowlistedgeneric")) {
    return;
  }

  const img = elem.querySelector<HTMLImageElement>(
    ".onebox-body img.thumbnail"
  );

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

function _handleLoadingOneboxImages(this: HTMLImageElement) {
  resolveSize(this);
  this.removeEventListener("load", _handleLoadingOneboxImages);
}

function loadNext(ajax: typeof discourseAjax): Promise<void> | undefined {
  if (loadingQueue.length === 0) {
    timeout = null;
    return;
  }

  let timeoutMs = 150;
  let removeLoading = true;
  const { url, refresh, elem, categoryId, topicId, onResolve } =
    loadingQueue.shift()!;

  // an earlier entry for the same url may have resolved while this one waited
  const cached = !refresh && lookupCache(url);
  if (cached) {
    const node = domFromString(cached)[0];
    onResolve?.(cached);
    elem.replaceWith(node);
    applySquareGenericOnebox(node);
    return loadNext(ajax);
  }

  // Retrieve the onebox
  return ajax<string>("/onebox", {
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
        onResolve?.(template);
        elem.replaceWith(node);
        applySquareGenericOnebox(node);
      },
      (result: Partial<AjaxError> | null | undefined) => {
        if (result?.jqXHR?.status === 429) {
          timeoutMs = 2000;
          removeLoading = false;
          loadingQueue.unshift({
            url,
            refresh,
            elem,
            categoryId,
            topicId,
            onResolve,
          });
        } else {
          setFailedCache(normalize(url), true);
          onResolve?.(null);
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

/**
 * Looks up the onebox of a link and replaces the link with it.
 *
 * It adds a loading class to the link and removes it when the lookup
 * completes or fails.
 *
 * @returns The cached onebox HTML when it is used, the loading promise when
 *   the load is synchronous, or `undefined` otherwise.
 */
export function load({
  elem,
  ajax,
  topicId,
  categoryId,
  refresh = true,
  offline = false,
  synchronous = false,
  onResolve,
}: {
  /** The link to onebox. */
  elem: HTMLAnchorElement;
  /** The function that makes the request. */
  ajax: typeof discourseAjax;
  /** The id of the topic the link is posted in. */
  topicId?: number;
  /** The id of the category the link is posted in. */
  categoryId?: number;
  /** Whether to skip the caches and fetch the onebox again. Defaults to true. */
  refresh?: boolean;
  /** Whether to only use the cache, without a request. */
  offline?: boolean;
  /** Whether to load now instead of after a short delay. */
  synchronous?: boolean;
  /** Called with the onebox HTML, or with `null` when the request fails. */
  onResolve?: (html: string | null) => void;
}): string | Promise<void> | undefined {
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
      onResolve?.(cached);
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
  loadingQueue.push({ url, refresh, elem, categoryId, topicId, onResolve });

  // Load next url in queue
  if (synchronous) {
    return loadNext(ajax);
  } else {
    timeout = timeout || discourseLater(() => loadNext(ajax), 150);
  }
}
