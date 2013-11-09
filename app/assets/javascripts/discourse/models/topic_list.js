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

    if (this.get('loadingMore')) { return Ember.RSVP.reject(); }

    var moreUrl = this.get('more_topics_url');
    if (moreUrl) {

      var topicList = this;
      this.set('loadingMore', true);

      return Discourse.ajax({url: moreUrl}).then(function (result) {
        var topicsAdded = 0;
        if (result) {
          // the new topics loaded from the server
          var newTopics = Discourse.TopicList.topicsFrom(result);
          var topics = topicList.get("topics");

          topicList.forEachNew(newTopics, function(t) {
            t.set('highlight', topicsAdded++ === 0);
            topics.pushObject(t);
          });

          topicList.set('more_topics_url', result.topic_list.more_topics_url);
          Discourse.Session.currentProp('topicList', topicList);
          topicList.set('loadingMore', false);

          return result.topic_list.more_topics_url;
        }
      });
    } else {
      // Return a promise indicating no more results
      return Ember.RSVP.reject();
    }
  },


  // loads topics with these ids "before" the current topics
  loadBefore: function(topic_ids){
    var topicList = this,
        topics = this.get('topics');

    // refresh dupes
    topics.removeObjects(topics.filter(function(topic){
      return topic_ids.indexOf(topic.get('id')) >= 0;
    }));

    Discourse.TopicList.loadTopics(topic_ids, this.get('filter'))
      .then(function(newTopics){
        topicList.forEachNew(newTopics, function(t) {
          // highlight the first of the new topics so we can get a visual feedback
          t.set('highlight', true);
          topics.insertAt(0,t);
        });
        Discourse.Session.currentProp('topicList', topicList);
      });
  }
});

Discourse.TopicList.reopenClass({

  loadTopics: function(topic_ids, filter) {
    var defer = new Ember.Deferred(),
        url = Discourse.getURL("/") + filter + "?topic_ids=" + topic_ids.join(",");

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

  /**
    Stitch together side loaded topic data

    @method topicsFrom
    @param {Object} JSON object with topic data
    @returns {Array} the list of topics
  **/
  topicsFrom: function(result) {
    // Stitch together our side loaded data
    var categories = Discourse.Category.list(),
        users = this.extractByKey(result.users, Discourse.User),
        topics = Em.A();

    return result.topic_list.topics.map(function (t) {
      t.category = categories.findBy('id', t.category_id);
      t.posters.forEach(function(p) {
        p.user = users[p.user_id];
      });
      return Discourse.Topic.create(t);
    });
  },

  /**
    Lists topics on a given menu item

    @method list
    @param {Object} The menu item to filter to
    @returns {Promise} a promise that resolves to the list of topics
  **/
  list: function(menuItem) {
    var filter = menuItem.get('name'),
        session = Discourse.Session.current(),
        list = session.get('topicList');

    if (list && (list.get('filter') === filter) && window.location.pathname.indexOf('more') > 0) {
      list.set('loaded', true);
      return Ember.RSVP.resolve(list);
    }
    session.setProperties({topicList: null, topicListScrollPos: null});
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
    };

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

