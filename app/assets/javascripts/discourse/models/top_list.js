/**
  A data model representing a list of top topic lists

  @class TopList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.TopList = Discourse.Model.extend({});

Discourse.TopList.reopenClass({
  find: function(period, category) {
    return PreloadStore.getAndRemove("top_lists", function() {
      var url = "";
      if (category) { url += category.get("url") + "/l"; }
      url += "/top";
      if (period) { url += "/" + period; }
      return Discourse.ajax(url + ".json");
    }).then(function (result) {
      var topList = Discourse.TopList.create({});

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
