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
      return $.ajax({url: moreUrl}).then(function (result) {
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
      return null;
    }
  },

  insert: function(json) {
    var newTopic  = Discourse.TopicList.decodeTopic(json);
    // new Topics are always unseen
    newTopic.set('unseen', true);
    // and highlighted on the topics list view
    newTopic.set('highlight', true);
    return this.get('inserted').unshiftObject(newTopic);
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
    var filter, list, promise, topic_list, url;
    filter = menuItem.name;
    topic_list = Discourse.TopicList.create();
    topic_list.set('inserted', Em.A());
    topic_list.set('filter', filter);
    url = Discourse.getURL("/") + filter + ".json";
    if (menuItem.filters && menuItem.filters.length > 0) {
      url += "?exclude_category=" + menuItem.filters[0].substring(1);
    }
    if (list = Discourse.get('transient.topicsList')) {
      if ((list.get('filter') === filter) && window.location.pathname.indexOf('more') > 0) {
        list.set('loaded', true);
        return Ember.Deferred.promise(function(promise) {
          promise.resolve(list);
        });
      }
    }
    Discourse.set('transient.topicsList', null);
    Discourse.set('transient.topicListScrollPos', null);

    return PreloadStore.getAndRemove("topic_list", function() { return $.getJSON(url) }).then(function(result) {
      topic_list.set('topics', Discourse.TopicList.topicsFrom(result));
      topic_list.set('can_create_topic', result.topic_list.can_create_topic);
      topic_list.set('more_topics_url', result.topic_list.more_topics_url);
      topic_list.set('filter_summary', result.topic_list.filter_summary);
      topic_list.set('draft_key', result.topic_list.draft_key);
      topic_list.set('draft_sequence', result.topic_list.draft_sequence);
      topic_list.set('draft', result.topic_list.draft);
      if (result.topic_list.filtered_category) {
        topic_list.set('category', Discourse.Category.create(result.topic_list.filtered_category));
      }
      topic_list.set('loaded', true);
      return topic_list;
    });
  }
});


