/**
  Helper for searching for Users

  @class UserSearch
  @namespace Discourse
  @module Discourse
**/
var cache = {};
var cacheTopicId = null;
var cacheTime = null;

var debouncedSearch = Discourse.debouncePromise(function(term, topicId) {
  return Discourse.ajax('/users/search/users', {
    data: {
      term: term,
      topic_id: topicId
    }
  }).then(function (r) {
    cache[term] = r;
    cacheTime = new Date();
    return r;
  });
}, 200);

Discourse.UserSearch = {

  search: function(options) {
    var term = options.term || "";
    var exclude = options.exclude || [];
    var topicId = options.topicId;
    var limit = options.limit || 5;

    var promise = Ember.Deferred.create();

    // TODO site setting for allowed regex in username
    if (term.match(/[^a-zA-Z0-9\_\.]/)) {
      promise.resolve([]);
      return promise;
    }
    if ((new Date() - cacheTime) > 30000) {
      cache = {};
    }
    if (cacheTopicId !== topicId) {
      cache = {};
    }
    cacheTopicId = topicId;

    var organizeResults = function(r) {
      var result = [];
      _.each(r.users,function(u) {
        if (exclude.indexOf(u.username) === -1) {
          result.push(u);
        }
        if (result.length > limit) return false;
        return true;
      });
      promise.resolve(result);
    };

    if (cache[term]) {
      organizeResults(cache[term]);
    } else {
      debouncedSearch(term, topicId).then(organizeResults);
    }
    return promise;
  }

};


