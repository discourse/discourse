/**
  This view handles rendering of a list of topics under discovery, with support
  for loading more as well as remembering your scroll position.

  @class ComboboxView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopicsView = Discourse.View.extend(Discourse.LoadMore, {
  eyelineSelector: '.topic-list-item',

  _scrollTop: function() {
    Em.run.schedule('afterRender', function() {
      $(document).scrollTop(0);
    });
  }.on('didInsertElement'),

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

