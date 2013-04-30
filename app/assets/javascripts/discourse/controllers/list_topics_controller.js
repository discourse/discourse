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

  latest: Ember.computed.equal('content.filter', 'latest'),

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
    this.get('content.topics').unshiftObjects(this.get('content.inserted'));

    // Clear inserted
    this.set('content.inserted', Em.A());
    return false;
  }
});


