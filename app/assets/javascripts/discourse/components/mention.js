/**
  Helps us determine whether someone has been mentioned by looking up their username.

  @class Mention
  @namespace Discourse
  @module Discourse
**/
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
      $.get(Discourse.getURL("/users/is_local_username"), {
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
    $elem = $(e);
    if ($elem.data('mention-tested')) {
      return;
    }
    username = $elem.text();
    username = username.substr(1);
    loading = lookup(username, function(valid) {
      if (valid) {
        return $elem.replaceWith("<a href='" + Discourse.getURL("/users/") + (username.toLowerCase()) + "' class='mention'>@" + username + "</a>");
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


