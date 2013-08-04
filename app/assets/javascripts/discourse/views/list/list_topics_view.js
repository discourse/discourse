/**
  This view handles the rendering of a topic list

  @class ListTopicsView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.LoadMore
  @module Discourse
**/
Discourse.ListTopicsView = Discourse.View.extend(Discourse.LoadMore, {
  templateName: 'list/topics',
  categoryBinding: 'controller.controllers.list.category',
  canCreateTopicBinding: 'controller.controllers.list.canCreateTopic',
  listBinding: 'controller.model',
  loadedMore: false,
  currentTopicId: null,
  eyelineSelector: '.topic-list-item',

  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

  didInsertElement: function() {
    this._super();
    Em.run.schedule('afterRender', function() {
      $('html, body').scrollTop(0);
    });
  },

  hasTopics: Em.computed.gt('list.topics.length', 0),
  showTable: Em.computed.or('hasTopics', 'topicTrackingState.hasIncoming'),

  updateTitle: function(){
    Discourse.notifyTitle(this.get('topicTrackingState.incomingCount'));
  }.observes('topicTrackingState.incomingCount'),

  loadMore: function() {
    var listTopicsView = this;
    Discourse.notifyTitle(0);
    listTopicsView.get('controller').loadMore().then(function (hasMoreResults) {
      Em.run.schedule('afterRender', function() {
        listTopicsView.saveScrollPosition();
      });
      if (!hasMoreResults) {
        listTopicsView.get('eyeline').flushRest();
      }
    });
  },

  // Remember where we were scrolled to
  saveScrollPosition: function() {
    Discourse.Session.current().set('topicListScrollPosition', $(window).scrollTop());
  },

  // When the topic list is scrolled
  scrolled: function(e) {
    this._super();
    this.saveScrollPosition();
  }


});


