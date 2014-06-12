/**
  This view handles rendering of a list of topics under discovery, with support
  for loading more as well as remembering your scroll position.

  @class DiscoveryTopicsView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Discourse.View.extend(Discourse.LoadMore, {
  eyelineSelector: '.topic-list-item',

  actions: {
    loadMore: function() {
      var self = this;
      Discourse.notifyTitle(0);
      this.get('controller').loadMoreTopics().then(function (hasMoreResults) {
        Em.run.schedule('afterRender', function() {
          self.saveScrollPosition();
        });
        if (!hasMoreResults) {
          self.get('eyeline').flushRest();
        }
      });
    }
  },

  _readjustScrollPosition: function() {
    var scrollTo = Discourse.Session.currentProp('topicListScrollPosition');

    if (typeof scrollTo !== "undefined") {
      Em.run.schedule('afterRender', function() {
        $(window).scrollTop(scrollTo+1);
      });
    }
  }.on('didInsertElement'),

  _updateTitle: function() {
    Discourse.notifyTitle(this.get('controller.topicTrackingState.incomingCount'));
  }.observes('controller.topicTrackingState.incomingCount'),

  // Remember where we were scrolled to
  saveScrollPosition: function() {
    Discourse.Session.current().set('topicListScrollPosition', $(window).scrollTop());
  },

  // When the topic list is scrolled
  scrolled: function() {
    this._super();
    this.saveScrollPosition();
  }
});

