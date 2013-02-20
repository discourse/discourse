(function() {

  window.Discourse.TopicList = Discourse.Model.extend({
    loadMoreTopics: function() {
      var moreUrl, promise,
        _this = this;
      promise = new RSVP.Promise();
      if (moreUrl = this.get('more_topics_url')) {
        Discourse.replaceState("/" + (this.get('filter')) + "/more");
        jQuery.ajax(moreUrl, {
          success: function(result) {
            var newTopics, topicIds, topics;
            if (result) {
              newTopics = Discourse.TopicList.topicsFrom(result);
              topics = _this.get('topics');
              topicIds = [];
              topics.each(function(t) {
                topicIds[t.get('id')] = true;
              });
              newTopics.each(function(t) {
                if (!topicIds[t.get('id')]) {
                  return topics.pushObject(t);
                }
              });
              _this.set('more_topics_url', result.topic_list.more_topics_url);
              Discourse.set('transient.topicsList', _this);
            }
            return promise.resolve(result.topic_list.more_topics_url ? true : false);
          }
        });
      } else {
        promise.resolve(false);
      }
      return promise;
    },
    insert: function(json) {
      var newTopic;
      newTopic = Discourse.TopicList.decodeTopic(json);
      /* New Topics are always unseen
      */

      newTopic.set('unseen', true);
      newTopic.set('highlightAfterInsert', true);
      return this.get('inserted').unshiftObject(newTopic);
    }
  });

  window.Discourse.TopicList.reopenClass({
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
      /* Stitch together our side loaded data
      */

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
      var filter, found, list, promise, topic_list, url;
      filter = menuItem.name;
      topic_list = Discourse.TopicList.create();
      topic_list.set('inserted', Em.A());
      topic_list.set('filter', filter);
      url = "/" + filter + ".json";
      if (menuItem.filters && menuItem.filters.length > 0) {
        url += "?exclude_category=" + menuItem.filters[0].substring(1);
      }
      if (list = Discourse.get('transient.topicsList')) {
        if ((list.get('filter') === filter) && window.location.pathname.indexOf('more') > 0) {
          promise = new RSVP.Promise();
          list.set('loaded', true);
          promise.resolve(list);
          return promise;
        }
      }
      Discourse.set('transient.topicsList', null);
      Discourse.set('transient.topicListScrollPos', null);
      promise = new RSVP.Promise();
      found = PreloadStore.contains('topic_list');
      PreloadStore.get("topic_list", function() {
        return jQuery.getJSON(url);
      }).then(function(result) {
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
        return promise.resolve(topic_list);
      });
      return promise;
    }
  });

}).call(this);
