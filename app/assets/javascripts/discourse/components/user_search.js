/**
  Helper for searching for Users

  @class UserSearch
  @namespace Discourse
  @module Discourse
**/
var cache = {};
var cacheTopicId = null;
var cacheTime = null;

var doSearch = function(term, topicId, success) {
  return Discourse.ajax({
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

var debouncedSearch = Discourse.debounce(doSearch, 200);

Discourse.UserSearch = {

  search: function(options) {
    var term = options.term || "";
    var callback = options.callback;
    var exclude = options.exclude || [];
    var topicId = options.topicId;
    var limit = options.limit || 5;
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
    var success = function(r) {
      var result = [];
      r.users.each(function(u) {
        if (exclude.indexOf(u.username) === -1) {
          result.push(u);
        }
        if (result.length > limit) return false;
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


