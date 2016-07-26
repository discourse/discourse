/**
  A helper for looking up oneboxes and displaying them

  For now it only stores in a local Javascript Object, in future we can change it so it uses localStorage
  or some other mechanism.
**/

const localCache = {};
const failedCache = {};

// Perform a lookup of a onebox based an anchor element. It will insert a loading
// indicator and remove it when the loading is complete or fails.
export function load(e, refresh, ajax) {
  var $elem = $(e);

  // If the onebox has loaded, return
  if ($elem.data('onebox-loaded')) return;
  if ($elem.hasClass('loading-onebox')) return;

  const url = e.href;

  // Unless we're forcing a refresh...
  if (!refresh) {
    // If we have it in our cache, return it.
    const cached = localCache[url];
    if (cached) return cached;

    // If the request failed, don't do anything
    const failed = failedCache[url];
    if (failed) return;
  }

  // Add the loading CSS class
  $elem.addClass('loading-onebox');

  // Retrieve the onebox
  return ajax("/onebox", {
    dataType: 'html',
    data: { url, refresh },
    cache: true
  }).then(html => {
    localCache[url] = html;
    $elem.replaceWith(html);
  }, function() {
    failedCache[url] = true;
  }).finally(() => {
    $elem.removeClass('loading-onebox');
    $elem.data('onebox-loaded');
  });
}

export function lookupCache(url) {
  return localCache[url];
}
