import UrlRefresh from 'discourse/mixins/url-refresh';
import LoadMore from "discourse/mixins/load-more";

export default Discourse.View.extend(LoadMore, UrlRefresh, {
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

