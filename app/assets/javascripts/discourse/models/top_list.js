/**
  A data model representing a list of top topic lists

  @class TopList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.TopList = Discourse.Model.extend({});

Discourse.TopList.reopenClass({
  find: function() {
    return PreloadStore.getAndRemove("top_list", function() {
      return Discourse.ajax("/top.json");
    }).then(function (result) {
      var topList = Discourse.TopList.create({
        can_create_topic: result.can_create_topic,
        yearly: Discourse.TopicList.from(result.yearly),
        monthly: Discourse.TopicList.from(result.monthly),
        weekly: Discourse.TopicList.from(result.weekly),
        daily: Discourse.TopicList.from(result.daily)
      });
      // disable sorting
      topList.setProperties({
        "yearly.sortOrder": undefined,
        "monthly.sortOrder": undefined,
        "weekly.sortOrder": undefined,
        "daily.sortOrder": undefined
      });
      return topList;
    });
  }
});
