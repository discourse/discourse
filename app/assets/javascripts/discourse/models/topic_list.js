/**
  A data model representing a list of topics

  @class TopicList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

function finderFor(filter, params) {

  return function() {
    var url = Discourse.getURL("/") + filter + ".json";

    if (params) {
      var keys = Object.keys(params),
          encoded = [];

      keys.forEach(function(p) {
        var value = params[p];
        if (typeof value !== 'undefined') {
          encoded.push(p + "=" + value);
        }
      });

      if (encoded.length > 0) {
        url += "?" + encoded.join('&');
      }
    }
    return Discourse.ajax(url);
  };
}

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

  refreshSort: function(order, ascending) {
    var self = this,
        params = this.get('params');

    params.order = order;
    params.ascending = ascending;

    this.set('loaded', false);
    var finder = finderFor(this.get('filter'), params);
    finder().then(function (result) {
      var newTopics = Discourse.TopicList.topicsFrom(result),
          topics = self.get('topics');

      topics.clear();
      topics.pushObjects(newTopics);
      self.setProperties({ loaded: true, more_topics_url: result.topic_list.more_topics_url });
    });
  },

  loadMore: function() {
    if (this.get('loadingMore')) { return Ember.RSVP.resolve(); }

    var moreUrl = this.get('more_topics_url');
    if (moreUrl) {

      var self = this;
      this.set('loadingMore', true);

      return Discourse.ajax({url: moreUrl}).then(function (result) {
        var topicsAdded = 0;
        if (result) {
          // the new topics loaded from the server
          var newTopics = Discourse.TopicList.topicsFrom(result),
              topics = self.get("topics");

          self.forEachNew(newTopics, function(t) {
            t.set('highlight', topicsAdded++ === 0);
            topics.pushObject(t);
          });

          self.setProperties({ loadingMore: false, more_topics_url: result.topic_list.more_topics_url });
          Discourse.Session.currentProp('topicList', self);
          return self.get('more_topics_url');
        }
      });
    } else {
      // Return a promise indicating no more results
      return Ember.RSVP.resolve();
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
    @param {Object} result JSON object with topic data
    @returns {Array} the list of topics
  **/
  topicsFrom: function(result) {
    // Stitch together our side loaded data
    var categories = Discourse.Category.list(),
        users = this.extractByKey(result.users, Discourse.User);

    return result.topic_list.topics.map(function (t) {
      t.category = categories.findBy('id', t.category_id);
      t.posters.forEach(function(p) {
        p.user = users[p.user_id];
      });
      if (t.participants) {
        t.participants.forEach(function(p) {
          p.user = users[p.user_id];
        });
      }
      return Discourse.Topic.create(t);
    });
  },

  from: function(result, filter, params) {
    var topicList = Discourse.TopicList.create({
      inserted: Em.A(),
      filter: filter,
      params: params || {},
      topics: Discourse.TopicList.topicsFrom(result),
      can_create_topic: result.topic_list.can_create_topic,
      more_topics_url: result.topic_list.more_topics_url,
      draft_key: result.topic_list.draft_key,
      draft_sequence: result.topic_list.draft_sequence,
      draft: result.topic_list.draft,
      loaded: true
    });

    if (result.topic_list.filtered_category) {
      topicList.set('category', Discourse.Category.create(result.topic_list.filtered_category));
    }

    return topicList;
  },

  /**
    Lists topics on a given menu item

    @method list
    @param {Object} filter The menu item to filter to
    @param {Object} params Any additional params to pass to TopicList.find()
    @returns {Promise} a promise that resolves to the list of topics
  **/
  list: function(filter, params) {
    var session = Discourse.Session.current(),
        list = session.get('topicList');

    if (list && (list.get('filter') === filter)) {
      list.set('loaded', true);
      return Ember.RSVP.resolve(list);
    }
    session.setProperties({topicList: null, topicListScrollPos: null});

    var findParams = {};
    Discourse.SiteSettings.top_menu.split('|').forEach(function (i) {
      if (i.indexOf(filter) === 0) {
        var exclude = i.split("-");
        if (exclude && exclude.length === 2) {
          findParams.exclude_category = exclude[1];
        }
      }
    });

    return Discourse.TopicList.find(filter, _.extend(findParams, params || {}));
  },

  find: function(filter, params) {
    return PreloadStore.getAndRemove("topic_list", finderFor(filter, params)).then(function(result) {
      return Discourse.TopicList.from(result, filter, params);
    });
  }

});

