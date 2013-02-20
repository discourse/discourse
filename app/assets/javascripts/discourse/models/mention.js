(function() {

  Discourse.Mention = (function() {
    var cache, load, localCache, lookup, lookupCache;
    localCache = {};
    cache = function(name, valid) {
      localCache[name] = valid;
    };
    lookupCache = function(name) {
      return localCache[name];
    };
    lookup = function(name, callback) {
      var cached;
      cached = lookupCache(name);
      if (cached === true || cached === false) {
        callback(cached);
        return false;
      } else {
        jQuery.get("/users/is_local_username", {
          username: name
        }, function(r) {
          cache(name, r.valid);
          return callback(r.valid);
        });
        return true;
      }
    };
    load = function(e) {
      var $elem, loading, username;
      $elem = jQuery(e);
      if ($elem.data('mention-tested')) {
        return;
      }
      username = $elem.text();
      username = username.substr(1);
      loading = lookup(username, function(valid) {
        if (valid) {
          return $elem.replaceWith("<a href='/users/" + (username.toLowerCase()) + "' class='mention'>@" + username + "</a>");
        } else {
          return $elem.removeClass('mention-loading').addClass('mention-tested');
        }
      });
      if (loading) {
        return $elem.addClass('mention-loading');
      }
    };
    return {
      load: load,
      lookup: lookup,
      lookupCache: lookupCache
    };
  })();

}).call(this);
