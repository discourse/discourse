let timeout;
const loadingQueue = [];
const localCache = {};
const failedCache = {};

function loadNext(ajax) {
  if (loadingQueue.length === 0) {
    timeout = null;
    return;
  }

  let timeoutMs = 150;
  let removeLoading = true;
  const { url, refresh, $elem, userId } = loadingQueue.shift();

  // Retrieve the onebox
  return ajax("/onebox", {
    dataType: 'html',
    data: { url, refresh, user_id: userId },
    cache: true
  }).then(html => {
    localCache[normalize(url)] = html;
    $elem.replaceWith(html);
  }, result => {
    if (result && result.jqXHR && result.jqXHR.status === 429) {
      timeoutMs = 2000;
      removeLoading = false;
      loadingQueue.unshift({ url, refresh, $elem, userId });
    } else {
      failedCache[normalize(url)] = true;
    }
  }).finally(() => {
    timeout = Ember.run.later(() => loadNext(ajax), timeoutMs);
    if (removeLoading) {
      $elem.removeClass('loading-onebox');
      $elem.data('onebox-loaded');
    }
  });
}

// Perform a lookup of a onebox based an anchor $element.
// It will insert a loading indicator and remove it when the loading is complete or fails.
export function load(e, refresh, ajax, userId, synchronous) {
  const $elem = $(e);

  // If the onebox has loaded or is loading, return
  if ($elem.data('onebox-loaded')) return;
  if ($elem.hasClass('loading-onebox')) return;

  const url = e.href;

  // Unless we're forcing a refresh...
  if (!refresh) {
    // If we have it in our cache, return it.
    const cached = localCache[normalize(url)];
    if (cached) return cached;

    // If the request failed, don't do anything
    const failed = failedCache[normalize(url)];
    if (failed) return;
  }

  // Add the loading CSS class
  $elem.addClass('loading-onebox');

  // Add to the loading queue
  loadingQueue.push({ url, refresh, $elem, userId });

  // Load next url in queue
  if (synchronous) {
    return loadNext(ajax);
  } else {
    timeout = timeout || Ember.run.later(() => loadNext(ajax), 150);
  }
}

// Sometimes jQuery will return URLs with trailing slashes when the
// `href` didn't have them.
function normalize(url) {
  return url.replace(/\/$/, '');
}

export function lookupCache(url) {
  return localCache[normalize(url)];
}
