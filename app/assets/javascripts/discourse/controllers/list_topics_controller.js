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

  filterModeChanged: function() {
    // Unsubscribe from a previous channel if necessary
    var previousChannel = this.get('previousChannel');
    if (previousChannel) {
      Discourse.MessageBus.unsubscribe("/" + previousChannel);
      this.set('previousChannel', null);
    }

    var filterMode = this.get('controllers.list.filterMode');
    if (!filterMode) return;

    var listTopicsController = this;
    Discourse.MessageBus.subscribe("/" + filterMode, function(data) {
      return listTopicsController.get('content').insert(data);
    });
    this.set('previousChannel', filterMode);

  }.observes('controllers.list.filterMode'),

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

  // Show rank details
  showRankDetails: function(topic) {
    var modalController = this.get('controllers.modal');
    if (modalController) {
      modalController.show(Discourse.TopicRankDetailsView.create({ topic: topic }));
    }
  },

  createTopic: function() {
    this.get('controllers.list').createTopic();
  },

  // Show newly inserted topics
  showInserted: function(e) {
    // Move inserted into topics
    this.get('topics').unshiftObjects(this.get('inserted'));

    // Clear inserted
    this.set('inserted', Em.A());
    return false;
  },

  allLoaded: function() {
    return !this.get('loading') && !this.get('more_topics_url');
  }.property('loading', 'more_topics_url'),

  canCreateTopic: Em.computed.alias('controllers.list.canCreateTopic'),

  footerMessage: function() {
    if (!this.get('allLoaded')) return;
    var category = this.get('category');
    if( category ) {
      return Em.String.i18n('topics.bottom.category', {category: category.get('name')});
    } else {
      var split = this.get('filter').split('/');
      if (this.get('topics.length') === 0) {
        return Em.String.i18n("topics.none." + split[0], {
          category: split[1]
        });
      } else {
        return Em.String.i18n("topics.bottom." + split[0], {
          category: split[1]
        });
      }
    }
  }.property('allLoaded', 'topics.length'),

  insertedCount: function() {
    var insertedLength = this.get('inserted.length');
    if (!insertedLength) return 0;
    return insertedLength;
  }.property('inserted.length'),

  rollUp: function() {
    return this.get('insertedCount') > Discourse.SiteSettings.new_topics_rollup;
  }.property('insertedCount'),

  loadMore: function() {
    this.set('loadingMore', true);
    var listTopicsController = this;
    return this.get('model').loadMoreTopics().then(function(hasMoreTopics) {
      listTopicsController.set('loadingMore', false);
      return hasMoreTopics;
    });
  }

});


