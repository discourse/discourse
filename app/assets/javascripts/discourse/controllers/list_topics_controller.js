/**
  This controller supports actions when listing topics or categories

  @class ListTopicsController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.ListTopicsController = Discourse.ObjectController.extend({
  needs: ['list', 'composer', 'modal'],
  rankDetailsVisible: false,

  // If we're changing our channel
  previousChannel: null,

  latest: Ember.computed.equal('filter', 'latest'),

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  draftLoaded: function() {
    var draft = this.get('content.draft');
    if (draft) {
      return this.get('controllers.composer').open({
        draft: draft,
        draftKey: this.get('content.draft_key'),
        draftSequence: this.get('content.draft_sequence'),
        ignoreIfChanged: true
      });
    }
  }.observes('content.draft'),

  actions: {
    // Star a topic
    toggleStar: function(topic) {
      topic.toggleStar();
    },

    // clear a pinned topic
    clearPin: function(topic) {
      topic.clearPin();
    },

    toggleRankDetails: function() {
      this.toggleProperty('rankDetailsVisible');
    },

    createTopic: function() {
      this.get('controllers.list').send('createTopic');
    },

    // Show newly inserted topics
    showInserted: function(e) {
      var tracker = Discourse.TopicTrackingState.current();

      // Move inserted into topics
      this.get('content').loadBefore(tracker.get('newIncoming'));
      tracker.resetTracking();
      return false;
    }
  },

  allLoaded: function() {
    return !this.get('loading') && !this.get('more_topics_url');
  }.property('loading', 'more_topics_url'),

  canCreateTopic: Em.computed.alias('controllers.list.canCreateTopic'),

  footerMessage: function() {
    if (!this.get('allLoaded')) return;
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

  loadMore: function() {
    var topicList = this.get('model');
    return topicList.loadMoreTopics().then(function(moreUrl) {
      if (!Em.isEmpty(moreUrl)) {
        Discourse.URL.replaceState(Discourse.getURL("/") + topicList.get('filter') + "/more");
      }
    });
  }

});


