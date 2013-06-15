/**
  A data model representing a list of topics

  @class TopicList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.TopicList = Discourse.Model.extend({

  forEachNew: function(topics, callback) {
    var topicIds = [];
    _.each(this.get('topics'),function(topic) {
      topicIds[topic.get('id')] = true;
    });

    _.each(topics,function(topic) {
      if(!topicIds[topic.id]) {
        callback(topic);
      }
    });
  },

  loadMoreTopics: function() {
    var moreUrl, _this = this;

    if (moreUrl = this.get('more_topics_url')) {
      Discourse.URL.replaceState(Discourse.getURL("/") + (this.get('filter')) + "/more");
      return Discourse.ajax({url: moreUrl}).then(function (result) {
        var newTopics, topics, topicsAdded = 0;
        if (result) {
          // the new topics loaded from the server
          newTopics = Discourse.TopicList.topicsFrom(result);
          topics = _this.get("topics");

          _this.forEachNew(newTopics, function(t) {
            t.set('highlight', topicsAdded++ === 0);
            topics.pushObject(t);
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


  // loads topics with these ids "before" the current topics
  loadBefore: function(topic_ids){
    var _this = this;
    var topics = this.get('topics');

    // refresh dupes
    topics.removeObjects(topics.filter(function(topic){
      return topic_ids.indexOf(topic.get('id')) >= 0;
    }));

    Discourse.TopicList.loadTopics(topic_ids, this.get('filter'))
      .then(function(newTopics){
        _this.forEachNew(newTopics, function(t) {
          // highlight the first of the new topics so we can get a visual feedback
          t.set('highlight', true);
          topics.insertAt(0,t);
        });
        Discourse.set('transient.topicsList', _this);

      });
  }
});

Discourse.TopicList.reopenClass({

  loadTopics: function(topic_ids, filter) {
    var defer = new Ember.Deferred();

    var url = Discourse.getURL("/") + filter + "?topic_ids=" + topic_ids.join(",");
    Discourse.ajax({url: url}).then(function (result) {
      if (result) {
        // the new topics loaded from the server
        var newTopics = Discourse.TopicList.topicsFrom(result);

        var topics = _(topic_ids)
          .map(function(id){
                  return newTopics.find(function(t){ return t.id === id; });
                })
          .compact()
          .value();

        defer.resolve(topics);
      } else {
        defer.reject();
      }
    }).then(null, function(){ defer.reject(); });

    return defer;
  },

  topicsFrom: function(result) {
    // Stitch together our side loaded data
    var categories, topics, users;
    categories = this.extractByKey(result.categories, Discourse.Category);
    users = this.extractByKey(result.users, Discourse.User);
    topics = Em.A();
    _.each(result.topic_list.topics,function(ft) {
      ft.category = categories[ft.category_id];
      _.each(ft.posters,function(p) {
        p.user = users[p.user_id];
      });
      topics.pushObject(Discourse.Topic.create(ft));
    });
    return topics;
  },

  list: function(menuItem) {
    var filter = menuItem.get('name');

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

    return Discourse.TopicList.find(filter, menuItem.get('excludeCategory'));
  }
});


Discourse.TopicList.reopenClass({

  find: function(filter, excludeCategory) {

    // How we find our topic list
    var finder = function() {
      var url = Discourse.getURL("/") + filter + ".json";
      if (excludeCategory) { url += "?exclude_category=" + excludeCategory; }
      return Discourse.ajax(url);
    }

    return PreloadStore.getAndRemove("topic_list", finder).then(function(result) {
      var topicList = Discourse.TopicList.create({
        inserted: Em.A(),
        filter: filter,
        topics: Discourse.TopicList.topicsFrom(result),
        can_create_topic: result.topic_list.can_create_topic,
        more_topics_url: result.topic_list.more_topics_url,
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

