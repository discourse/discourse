/**
  Helper for searching for Users

  @class UserSearch
  @namespace Discourse
  @module Discourse
**/
var cache = {};
var cacheTopicId = null;
var cacheTime = null;

var currentTerm;

var debouncedSearch = _.debounce(function(term, topicId, include_groups, resultsFn) {

  Discourse.ajax('/users/search/users', {
    data: {
      term: term,
      topic_id: topicId,
      include_groups: include_groups
    }
  }).then(function (r) {

    cache[term] = r;
    cacheTime = new Date();

    if(term === currentTerm){
      resultsFn(r);
    }
  });

}, 300);

Discourse.UserSearch = {

  search: function(options) {
    var term = options.term || "";
    currentTerm = term;

    var include_groups = options.include_groups || false;
    var exclude = options.exclude || [];
    var topicId = options.topicId;
    var limit = options.limit || 5;

    var promise = Ember.Deferred.create();

    // TODO site setting for allowed regex in username
    if (term.match(/[^a-zA-Z0-9_\.]/)) {
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
      var users = [], groups = [], results = [];
      _.each(r.users,function(u) {
        if (exclude.indexOf(u.username) === -1) {
          users.push(u);
          results.push(u);
        }
        return results.length <= limit;
      });

      _.each(r.groups,function(g) {
        if (results.length > limit) return false;
        if (exclude.indexOf(g.name) === -1) {
          groups.push(g);
          results.push(g);
        }
        return true;
      });

      results.users = users;
      results.groups = groups;

      promise.resolve(results);
    };

    if (cache[term]) {
      // inject a delay to avoid too much repainting
      setTimeout(function(){
        if(term !== currentTerm) {
          return;
        }
        organizeResults(cache[term]);
      }, 300);
    } else {
      debouncedSearch(term, topicId, include_groups, organizeResults);
    }

    return promise;
  }

};


