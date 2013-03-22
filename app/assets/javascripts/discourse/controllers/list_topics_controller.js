/**
  This controller supports actions when listing topics or categories

  @class ListTopicsController 
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.ListTopicsController = Discourse.ObjectController.extend({
  needs: ['list', 'composer'],
  // If we're changing our channel
  previousChannel: null,

  popular: (function() {
    return this.get('content.filter') === 'popular';
  }).property('content.filter'),

  filterModeChanged: (function() {
    // Unsubscribe from a previous channel if necessary
    var channel, filterMode, previousChannel,
      _this = this;
    if (previousChannel = this.get('previousChannel')) {
      Discourse.MessageBus.unsubscribe("/" + previousChannel);
      this.set('previousChannel', null);
    }
    filterMode = this.get('controllers.list.filterMode');
    if (!filterMode) {
      return;
    }
    channel = filterMode;
    Discourse.MessageBus.subscribe("/" + channel, function(data) {
      return _this.get('content').insert(data);
    });
    return this.set('previousChannel', channel);
  }).observes('controllers.list.filterMode'),
  draftLoaded: (function() {
    var draft;
    draft = this.get('content.draft');
    if (draft) {
      return this.get('controllers.composer').open({
        draft: draft,
        draftKey: this.get('content.draft_key'),
        draftSequence: this.get('content.draft_sequence'),
        ignoreIfChanged: true
      });
    }
  }).observes('content.draft'),

  // Star a topic
  toggleStar: function(topic) {
    topic.toggleStar();
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


