/**
  The controller for displaying a list of topics.

  @class DiscoveryTopicsController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopicsController = Discourse.DiscoveryController.extend({
  bulkSelectEnabled: false,
  selected: [],

  actions: {
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
        self.setProperties({ model: list, selected: [] });

        var tracking = Discourse.TopicTrackingState.current();
        if (tracking) {
          tracking.sync(list, filter);
        }

        self.send('loadingComplete');
      });
    },

    toggleBulkSelect: function() {
      this.toggleProperty('bulkSelectEnabled');
      this.get('selected').clear();
    },

    resetNew: function() {
      var self = this;

      Discourse.TopicTrackingState.current().resetNew();
      Discourse.Topic.resetNew().then(function() {
        self.send('refresh');
      });
    },

    dismissRead: function() {
      var self = this,
          selected = this.get('selected'),
          operation = { type: 'change_notification_level',
                        notification_level_id: Discourse.Topic.NotificationLevel.REGULAR };

      var promise;
      if (selected.length > 0) {
        promise = Discourse.Topic.bulkOperation(selected, operation);
      } else {
        promise = Discourse.Topic.bulkOperationByFilter(this.get('filter'), operation);
      }
      promise.then(function() { self.send('refresh'); });
    }
  },


  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

  showDismissRead: function() {
    return this.get('filter') === 'unread' && this.get('topics.length') > 0;
  }.property('filter', 'topics.length'),

  showResetNew: function() {
    return this.get('filter') === 'new' && this.get('topics.length') > 0;
  }.property('filter', 'topics.length'),

  canBulkSelect: Em.computed.alias('currentUser.staff'),
  hasTopics: Em.computed.gt('topics.length', 0),
  showTable: Em.computed.or('hasTopics', 'topicTrackingState.hasIncoming'),
  allLoaded: Em.computed.empty('more_topics_url'),
  latest: Discourse.computed.endWith('filter', 'latest'),
  top: Em.computed.notEmpty('period'),
  yearly: Em.computed.equal('period', 'yearly'),
  monthly: Em.computed.equal('period', 'monthly'),
  weekly: Em.computed.equal('period', 'weekly'),
  daily: Em.computed.equal('period', 'daily'),

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
