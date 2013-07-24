/**
  This view handles the rendering of a topic list

  @class ListTopicsView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.Scrolling
  @module Discourse
**/
Discourse.ListTopicsView = Discourse.View.extend(Discourse.Scrolling, {
  templateName: 'list/topics',
  categoryBinding: 'controller.controllers.list.category',
  canCreateTopicBinding: 'controller.controllers.list.canCreateTopic',
  listBinding: 'controller.model',
  loadedMore: false,
  currentTopicId: null,

  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

  willDestroyElement: function() {
    this.unbindScrolling();
  },

  didInsertElement: function() {
    this.bindScrolling();
    var eyeline = new Discourse.Eyeline('.topic-list-item');

    var listTopicsView = this;
    eyeline.on('sawBottom', function() {
      listTopicsView.loadMore();
    });

    var scrollPos = Discourse.get('transient.topicListScrollPos');
    if (scrollPos) {
      Em.run.schedule('afterRender', function() {
        $('html, body').scrollTop(scrollPos);
      });
    } else {
      Em.run.schedule('afterRender', function() {
        $('html, body').scrollTop(0);
      });
    }
    this.set('eyeline', eyeline);
  },

  showTable: function() {
    var topics = this.get('list.topics');
    if(topics) {
      return this.get('list.topics').length > 0 || this.get('topicTrackingState.hasIncoming');
    }
  }.property('list.topics.@each','topicTrackingState.hasIncoming'),

  updateTitle: function(){
    Discourse.notifyTitle(this.get('topicTrackingState.incomingCount'));
  }.observes('topicTrackingState.incomingCount'),

  loadMore: function() {
    var listTopicsView = this;
    Discourse.notifyTitle(0);
    listTopicsView.get('controller').loadMore().then(function (hasMoreResults) {
      Em.run.schedule('afterRender', function() {
        listTopicsView.saveScrollPos();
      });
      if (!hasMoreResults) {
        listTopicsView.get('eyeline').flushRest();
      }
    });
  },

  // Remember where we were scrolled to
  saveScrollPos: function() {
    return Discourse.set('transient.topicListScrollPos', $(window).scrollTop());
  },

  // When the topic list is scrolled
  scrolled: function(e) {
    this.saveScrollPos();
    var eyeline = this.get('eyeline');
    if (eyeline) { eyeline.update(); }
  }


});


