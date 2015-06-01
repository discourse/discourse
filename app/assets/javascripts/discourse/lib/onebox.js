/**
  A helper for looking up oneboxes and displaying them

  For now it only stores in a local Javascript Object, in future we can change it so it uses localStorage
  or some other mechanism.

  @class Onebox
  @namespace Discourse
  @module Discourse
**/
Discourse.Onebox = {

  // The cache is just a JS Object
  localCache: {},

  // A cache of failed URLs
  failedCache: {},

  /**
    Perform a lookup of a onebox based an anchor element. It will insert a loading
    indicator and remove it when the loading is complete or fails.

    @method load
    @param {HTMLElement} e the anchor element whose onebox we want to look up
    @param {Boolean} refresh true if we want to force a refresh of the onebox
  **/
  load: function(e, refresh) {

    var $elem = $(e);

    // If the onebox has loaded, return
    if ($elem.data('onebox-loaded')) return;
    if ($elem.hasClass('loading-onebox')) return;

    var url = e.href;

    // Unless we're forcing a refresh...
    if (!refresh) {
      // If we have it in our cache, return it.
      var cached = this.localCache[url];
      if (cached) return cached;

      // If the request failed, don't do anything
      var failed = this.failedCache[url];
      if (failed) return;
    }

    // Add the loading CSS class
    $elem.addClass('loading-onebox');

    // Retrieve the onebox
    var promise = Discourse.ajax("/onebox", {
      dataType: 'html',
      data: { url: url, refresh: refresh },
      cache: true
    });

    // We can call this when loading is complete
    var loadingFinished = function() {
      $elem.removeClass('loading-onebox');
      $elem.data('onebox-loaded');
    };

    var onebox = this;
    promise.then(function(html) {

      // loaded onebox
      loadingFinished();

      onebox.localCache[url] = html;
      $elem.replaceWith(html);

    }, function() {
      // If the request failed log it as such
      onebox.failedCache[url] = true;
      loadingFinished();
    });

  },

  /**
    Return the cached contents of a Onebox

    @method lookupCache
    @param {String} url the url of the onebox
    @return {String} the cached contents of the onebox or null if not found
  **/
  lookupCache: function(url) {
    return this.localCache[url];
  },

  /**
    Store the contents of a Onebox in our local cache.

    @method cache
    @private
    @param {String} url the url of the onebox we crawled
    @param {String} contents the contents we want to cache
  **/
  cache: function(url, contents) {
    this.localCache[url] = contents;
  }

};


