/**
  Helper for searching for Users

  @class UserSearch
  @namespace Discourse
  @module Discourse
**/
var cache, cacheTime, cacheTopicId, debouncedSearch, doSearch;

cache = {};

cacheTopicId = null;

cacheTime = null;

doSearch = function(term, topicId, success) {
  return $.ajax({
    url: Discourse.getURL('/users/search/users'),
    dataType: 'JSON',
    data: {
      term: term,
      topic_id: topicId
    },
    success: function(r) {
      cache[term] = r;
      cacheTime = new Date();
      return success(r);
    }
  });
};

debouncedSearch = Discourse.debounce(doSearch, 200);

Discourse.UserSearch = {
  search: function(options) {
    var callback, exclude, limit, success, term, topicId;
    term = options.term || "";
    callback = options.callback;
    exclude = options.exclude || [];
    topicId = options.topicId;
    limit = options.limit || 5;
    if (!callback) {
      throw "missing callback";
    }

    // TODO site setting for allowed regex in username
    if (term.match(/[^a-zA-Z0-9\_\.]/)) {
      callback([]);
      return true;
    }
    if ((new Date() - cacheTime) > 30000) {
      cache = {};
    }
    if (cacheTopicId !== topicId) {
      cache = {};
    }
    cacheTopicId = topicId;
    success = function(r) {
      var result;
      result = [];
      r.users.each(function(u) {
        if (exclude.indexOf(u.username) === -1) {
          result.push(u);
        }
        if (result.length > limit) {
          return false;
        }
        return true;
      });
      return callback(result);
    };
    if (cache[term]) {
      success(cache[term]);
    } else {
      debouncedSearch(term, topicId, success);
    }
    return true;
  }
};


