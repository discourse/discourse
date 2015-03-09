/* global assetPath */

const _loaded = {};

export default function loadScript(url) {
  return new Ember.RSVP.Promise(function(resolve) {
    url = Discourse.getURL((assetPath && assetPath(url)) || url);

    // If we already loaded this url
    if (_loaded[url]) { return resolve(); }

    $.getScript(url).then(function() {
      _loaded[url] = true;
      resolve();
    });
  });
}
