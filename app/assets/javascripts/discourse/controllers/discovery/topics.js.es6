import DiscoveryController from 'discourse/controllers/discovery';
import { queryParams } from 'discourse/controllers/discovery-sortable';
import BulkTopicSelection from 'discourse/mixins/bulk-topic-selection';
import { endWith } from 'discourse/lib/computed';

const controllerOpts = {
  needs: ['discovery'],
  period: null,

  canStar: Em.computed.alias('controllers.discovery/topics.currentUser.id'),
  showTopicPostBadges: Em.computed.not('controllers.discovery/topics.new'),

  redirectedReason: Em.computed.alias('currentUser.redirected_to_top.reason'),

  order: 'default',
  ascending: false,
  expandGloballyPinned: false,
  expandAllPinned: false,

  actions: {

    changeSort(sortBy) {
      if (sortBy === this.get('order')) {
        this.toggleProperty('ascending');
      } else {
        this.setProperties({ order: sortBy, ascending: false });
      }
      this.get('model').refreshSort(sortBy, this.get('ascending'));
    },

    // Show newly inserted topics
    showInserted() {
      const tracker = this.topicTrackingState;

      // Move inserted into topics
      this.get('content').loadBefore(tracker.get('newIncoming'));
      tracker.resetTracking();
      return false;
    },

    refresh() {
      const filter = this.get('model.filter');

      this.setProperties({ order: 'default', ascending: false });

      // Don't refresh if we're still loading
      if (this.get('controllers.discovery.loading')) { return; }

      // If we `send('loading')` here, due to returning true it bubbles up to the
      // router and ember throws an error due to missing `handlerInfos`.
      // Lesson learned: Don't call `loading` yourself.
      this.set('controllers.discovery.loading', true);

      this.store.findFiltered('topicList', {filter}).then((list) => {
        Discourse.TopicList.hideUniformCategory(list, this.get('category'));

        this.setProperties({ model: list });
        this.resetSelected();

        if (this.topicTrackingState) {
          this.topicTrackingState.sync(list, filter);
        }

        this.send('loadingComplete');
      });
    },


    resetNew() {
      this.topicTrackingState.resetNew();
      Discourse.Topic.resetNew().then(() => this.send('refresh'));
    }
  },

  isFilterPage: function(filter, filterType) {
    if (!filter) { return false; }
    return filter.match(new RegExp(filterType + '$', 'gi')) ? true : false;
  },

  showDismissRead: function() {
    return this.isFilterPage(this.get('model.filter'), 'unread') && this.get('model.topics.length') > 0;
  }.property('model.filter', 'model.topics.length'),

  showResetNew: function() {
    return this.get('model.filter') === 'new' && this.get('model.topics.length') > 0;
  }.property('model.filter', 'model.topics.length'),

  showDismissAtTop: function() {
    return (this.isFilterPage(this.get('model.filter'), 'new') ||
           this.isFilterPage(this.get('model.filter'), 'unread')) &&
           this.get('model.topics.length') >= 30;
  }.property('model.filter', 'model.topics.length'),

  hasTopics: Em.computed.gt('model.topics.length', 0),
  allLoaded: Em.computed.empty('model.more_topics_url'),
  latest: endWith('model.filter', 'latest'),
  new: endWith('model.filter', 'new'),
  top: Em.computed.notEmpty('period'),
  yearly: Em.computed.equal('period', 'yearly'),
  quarterly: Em.computed.equal('period', 'quarterly'),
  monthly: Em.computed.equal('period', 'monthly'),
  weekly: Em.computed.equal('period', 'weekly'),
  daily: Em.computed.equal('period', 'daily'),

  footerMessage: function() {
    if (!this.get('allLoaded')) { return; }

    const category = this.get('category');
    if( category ) {
      return I18n.t('topics.bottom.category', {category: category.get('name')});
    } else {
      const split = (this.get('model.filter') || '').split('/');
      if (this.get('model.topics.length') === 0) {
        return I18n.t("topics.none." + split[0], {
          category: split[1]
        });
      } else {
        return I18n.t("topics.bottom." + split[0], {
          category: split[1]
        });
      }
    }
  }.property('allLoaded', 'model.topics.length'),

  footerEducation: function() {
    if (!this.get('allLoaded') || this.get('model.topics.length') > 0 || !Discourse.User.current()) { return; }

    const split = (this.get('model.filter') || '').split('/');

    if (split[0] !== 'new' && split[0] !== 'unread') { return; }

    return I18n.t("topics.none.educate." + split[0], {
      userPrefsUrl: Discourse.getURL("/users/") + (Discourse.User.currentProp("username_lower")) + "/preferences"
    });
  }.property('allLoaded', 'model.topics.length'),

  loadMoreTopics() {
    return this.get('model').loadMore();
  }
};

Ember.keys(queryParams).forEach(function(p) {
  // If we don't have a default value, initialize it to null
  if (typeof controllerOpts[p] === 'undefined') {
    controllerOpts[p] = null;
  }
});

export default DiscoveryController.extend(controllerOpts, BulkTopicSelection);
