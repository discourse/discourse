/**
  A data model representing a list of topics

  @class TopicList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.TopicList = Discourse.Model.extend({

  loadMoreTopics: function() {
    var moreUrl, _this = this;

    if (moreUrl = this.get('more_topics_url')) {
      Discourse.URL.replaceState(Discourse.getURL("/") + (this.get('filter')) + "/more");
      return Discourse.ajax({url: moreUrl}).then(function (result) {
        var newTopics, topicIds, topics, topicsAdded = 0;
        if (result) {
          // the new topics loaded from the server
          newTopics = Discourse.TopicList.topicsFrom(result);
          // the current topics
          topics = _this.get('topics');
          // keeps track of the ids of the current topics
          topicIds = [];
          topics.each(function(t) {
            topicIds[t.get('id')] = true;
          });
          // add new topics to the list of current topics if not already present
          newTopics.each(function(t) {
            if (!topicIds[t.get('id')]) {
              // highlight the first of the new topics so we can get a visual feedback
              t.set('highlight', topicsAdded++ === 0);
              return topics.pushObject(t);
            }
          });
          _this.set('more_topics_url', result.topic_list.more_topics_url);
          Discourse.set('transient.topicsList', _this);
        }
        return result.topic_list.more_topics_url;
      });
    } else {
      // Return a promise indicating no more results
      return Ember.Deferred.promise(function (p) {
        p.resolve(false);
      });
    }
  },

  insert: function(json) {
    var newTopic  = Discourse.TopicList.decodeTopic(json);
    newTopic.setProperties({
      unseen: true,
      highlight: true
    });
    this.get('inserted').unshiftObject(newTopic);
  }

});

Discourse.TopicList.reopenClass({

  decodeTopic: function(result) {
    var categories, topic, users;
    categories = this.extractByKey(result.categories, Discourse.Category);
    users = this.extractByKey(result.users, Discourse.User);
    topic = result.topic_list_item;
    topic.category = categories[topic.category];
    topic.posters.each(function(p) {
      p.user = users[p.user_id] || users[p.user];
    });
    return Discourse.Topic.create(topic);
  },

  topicsFrom: function(result) {
    // Stitch together our side loaded data
    var categories, topics, users;
    categories = this.extractByKey(result.categories, Discourse.Category);
    users = this.extractByKey(result.users, Discourse.User);
    topics = Em.A();
    result.topic_list.topics.each(function(ft) {
      ft.category = categories[ft.category_id];
      ft.posters.each(function(p) {
        p.user = users[p.user_id];
      });
      return topics.pushObject(Discourse.Topic.create(ft));
    });
    return topics;
  },

  list: function(menuItem) {
    var filter = menuItem.name;

    var topicList = Discourse.TopicList.create({
      inserted: Em.A(),
      filter: filter
    });

    var url = Discourse.getURL("/") + filter + ".json";
    if (menuItem.filters && menuItem.filters.length > 0) {
      url += "?exclude_category=" + menuItem.filters[0].substring(1);
    }

    var list = Discourse.get('transient.topicsList');
    if (list) {
      if ((list.get('filter') === filter) && window.location.pathname.indexOf('more') > 0) {
        list.set('loaded', true);
        return Ember.Deferred.promise(function(promise) {
          promise.resolve(list);
        });
      }
    }
    Discourse.set('transient.topicsList', null);
    Discourse.set('transient.topicListScrollPos', null);

    return PreloadStore.getAndRemove("topic_list", function() { return Discourse.ajax(url) }).then(function(result) {
      topicList.setProperties({
        topics: Discourse.TopicList.topicsFrom(result),
        can_create_topic: result.topic_list.can_create_topic,
        more_topics_url: result.topic_list.more_topics_url,
        filter_summary: result.topic_list.filter_summary,
        draft_key: result.topic_list.draft_key,
        draft_sequence: result.topic_list.draft_sequence,
        draft: result.topic_list.draft,
        canViewRankDetails: result.topic_list.can_view_rank_details,
        loaded: true
      });

      if (result.topic_list.filtered_category) {
        topicList.set('category', Discourse.Category.create(result.topic_list.filtered_category));
      }
      return topicList;
    });
  }
});


