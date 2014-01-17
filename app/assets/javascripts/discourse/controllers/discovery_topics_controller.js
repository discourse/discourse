/**
  The controller for displaying a list of topics.

  @class DiscoveryTopicsController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopicsController = Discourse.ObjectController.extend({
  actions: {
    // Star a topic
    toggleStar: function(topic) {
      topic.toggleStar();
    },

    // clear a pinned topic
    clearPin: function(topic) {
      topic.clearPin();
    },

    // Show newly inserted topics
    showInserted: function() {
      var tracker = Discourse.TopicTrackingState.current();

      // Move inserted into topics
      this.get('content').loadBefore(tracker.get('newIncoming'));
      tracker.resetTracking();
      return false;
    },

    refresh: function() {
      var filter = this.get('model.filter'),
          self = this;

      this.send('loading');
      Discourse.TopicList.find(filter).then(function(list) {
        self.set('model', list);
        self.send('loadingComplete');
      });
    }
  },

  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

  hasTopics: Em.computed.gt('topics.length', 0),
  showTable: Em.computed.or('hasTopics', 'topicTrackingState.hasIncoming'),
  latest: Em.computed.equal('filter', 'latest'),
  allLoaded: Em.computed.empty('more_topics_url'),

  updateTitle: function(){
    Discourse.notifyTitle(this.get('topicTrackingState.incomingCount'));
  }.observes('topicTrackingState.incomingCount'),

  footerMessage: function() {
    if (!this.get('allLoaded')) { return; }

    var category = this.get('category');
    if( category ) {
      return I18n.t('topics.bottom.category', {category: category.get('name')});
    } else {
      var split = this.get('filter').split('/');
      if (this.get('topics.length') === 0) {
        return I18n.t("topics.none." + split[0], {
          category: split[1]
        });
      } else {
        return I18n.t("topics.bottom." + split[0], {
          category: split[1]
        });
      }
    }
  }.property('allLoaded', 'topics.length'),

  loadMoreTopics: function() {
    var topicList = this.get('model');
    return topicList.loadMore().then(function(moreUrl) {
      if (!Em.isEmpty(moreUrl)) {
        Discourse.URL.replaceState(Discourse.getURL("/") + topicList.get('filter') + "/more");
      }
    });
  }
});
