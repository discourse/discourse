(function() {

  Discourse.Onebox = (function() {
    /* for now it only stores in a var, in future we can change it so it uses localStorage,
    */

    /*  trouble with localStorage is that expire semantics need some thinking
    */

    /*cacheKey = "__onebox__"
    */

    var cache, load, localCache, lookup, lookupCache;
    localCache = {};
    cache = function(url, contents) {
      localCache[url] = contents;
      return null;
    };
    lookupCache = function(url) {
      var cached;
      cached = localCache[url];
      if (cached && cached.then) {
        return null;
      } else {
        return cached;
      }
    };
    lookup = function(url, refresh, callback) {
      var cached;
      cached = localCache[url];
      if (refresh && cached && !cached.then) {
        cached = null;
      }
      if (cached) {
        if (cached.then) {
          cached.then(callback(lookupCache(url)));
        } else {
          callback(cached);
        }
        return false;
      } else {
        cache(url, jQuery.get("/onebox", {
          url: url,
          refresh: refresh
        }, function(html) {
          cache(url, html);
          return callback(html);
        }));
        return true;
      }
    };
    load = function(e, refresh) {
      var $elem, loading, url;
      if (!refresh) refresh = false;

      url = e.href;
      $elem = jQuery(e);
      if ($elem.data('onebox-loaded')) {
        return;
      }
      loading = lookup(url, refresh, function(html) {
        $elem.removeClass('loading-onebox');
        $elem.data('onebox-loaded');
        if (!html) {
          return;
        }
        if (html.trim().length === 0) {
          return;
        }
        return $elem.replaceWith(html);
      });
      if (loading) {
        return $elem.addClass('loading-onebox');
      }
    };
    return {
      load: load,
      lookup: lookup,
      lookupCache: lookupCache
    };
  })();

}).call(this);
