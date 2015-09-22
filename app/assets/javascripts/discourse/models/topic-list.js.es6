import RestModel from 'discourse/models/rest';
import Model from 'discourse/models/model';

function topicsFrom(result, store) {
  if (!result) { return; }

  // Stitch together our side loaded data
  const categories = Discourse.Category.list(),
        users = Model.extractByKey(result.users, Discourse.User);

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
    return store.createRecord('topic', t);
  });
}

const TopicList = RestModel.extend({
  canLoadMore: Em.computed.notEmpty("more_topics_url"),

  forEachNew: function(topics, callback) {
    const topicIds = [];
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
    const self = this;
    var params = this.get('params') || {};

    params.order = order || params.order;

    if (ascending === undefined) {
      params.ascending = ascending;
    } else {
      params.ascending = ascending;
    }

    if (params.q) {
      // search is unique, nothing else allowed with it
      params = {q: params.q};
    }

    this.set('loaded', false);
    this.set('params', params);

    const store = this.store;
    store.findFiltered('topicList', {filter: this.get('filter'), params}).then(function(tl) {
      const newTopics = tl.get('topics'),
            topics = self.get('topics');

      topics.clear();
      topics.pushObjects(newTopics);
      self.setProperties({ loaded: true, more_topics_url: tl.get('topic_list.more_topics_url') });
    });
  },

  loadMore: function() {
    if (this.get('loadingMore')) { return Ember.RSVP.resolve(); }

    const moreUrl = this.get('more_topics_url');
    if (moreUrl) {
      const self = this;
      this.set('loadingMore', true);

      const store = this.store;
      return Discourse.ajax({url: moreUrl}).then(function (result) {
        let topicsAdded = 0;

        if (result) {
          // the new topics loaded from the server
          const newTopics = topicsFrom(result, store),
              topics = self.get("topics");

          self.forEachNew(newTopics, function(t) {
            t.set('highlight', topicsAdded++ === 0);
            topics.pushObject(t);
          });

          self.setProperties({
            loadingMore: false,
            more_topics_url: result.topic_list.more_topics_url
          });

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
    const topicList = this,
        topics = this.get('topics');

    // refresh dupes
    topics.removeObjects(topics.filter(function(topic){
      return topic_ids.indexOf(topic.get('id')) >= 0;
    }));

    const url = Discourse.getURL("/") + this.get('filter') + "?topic_ids=" + topic_ids.join(",");

    const store = this.store;
    return Discourse.ajax({ url }).then(function(result) {
      let i = 0;
      topicList.forEachNew(topicsFrom(result, store), function(t) {
        // highlight the first of the new topics so we can get a visual feedback
        t.set('highlight', true);
        topics.insertAt(i,t);
        i++;
      });
      Discourse.Session.currentProp('topicList', topicList);
    });
  }
});

TopicList.reopenClass({

  munge(json, store) {
    json.inserted = json.inserted || [];
    json.can_create_topic = json.topic_list.can_create_topic;
    json.more_topics_url = json.topic_list.more_topics_url;
    json.draft_key = json.topic_list.draft_key;
    json.draft_sequence = json.topic_list.draft_sequence;
    json.draft = json.topic_list.draft;
    json.for_period = json.topic_list.for_period;
    json.loaded = true;
    json.per_page = json.topic_list.per_page;
    json.topics = topicsFrom(json, store);

    return json;
  },

  find(filter, params) {
    const store = Discourse.__container__.lookup('store:main');
    return store.findFiltered('topicList', {filter, params});
  },

  list(filter) {
    Ember.warn('`Discourse.TopicList.list` is deprecated. Use the store instead');
    return this.find(filter);
  },

  // hide the category when it has no children
  hideUniformCategory(list, category) {
    list.set('hideCategory', category && !category.get("has_children"));
  }

});

export default TopicList;
