/**
  Helps us determine whether someone has been mentioned by looking up their username.

  @class Mention
  @namespace Discourse
  @module Discourse
**/
Discourse.Mention = (function() {
  var localCache = {};

  var cache = function(name, valid) {
    localCache[name] = valid;
  };

  var lookupCache = function(name) {
    return localCache[name];
  };

  var lookup = function(name, callback) {
    var cached = lookupCache(name);
    if (cached === true || cached === false) {
      callback(cached);
      return false;
    } else {
      Discourse.ajax("/users/is_local_username", { data: { username: name } }).then(function(r) {
        cache(name, r.valid);
        callback(r.valid);
      });
      return true;
    }
  };

  var load = function(e) {
    var $elem = $(e);
    if ($elem.data('mention-tested')) return;
    var username = $elem.text();
    username = username.substr(1);
    var loading = lookup(username, function(valid) {
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

  return { load: load, lookup: lookup, lookupCache: lookupCache };
})();


