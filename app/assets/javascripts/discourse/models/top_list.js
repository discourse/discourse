/**
  A data model representing a list of top topic lists

  @class TopList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.TopList = Discourse.Model.extend({});

Discourse.TopList.reopenClass({
  find: function(filter) {
    return PreloadStore.getAndRemove("top_lists", function() {
      var url = Discourse.getURL("/") + (filter || "top") + ".json";
      return Discourse.ajax(url);
    }).then(function (result) {
      var topList = Discourse.TopList.create({ can_create_topic: result.can_create_topic });

      Discourse.Site.currentProp('periods').forEach(function(period) {
        // if there is a list for that period
        if (result[period]) {
          // instanciate a new topic list with no sorting
          topList.set(period, Discourse.TopicList.from(result[period]));
          topList.set(period + ".sortOrder", undefined);
        }
      });

      return topList;
    });
  }
});
