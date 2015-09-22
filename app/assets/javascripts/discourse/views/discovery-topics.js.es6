import UrlRefresh from 'discourse/mixins/url-refresh';
import LoadMore from "discourse/mixins/load-more";
import { on, observes } from "ember-addons/ember-computed-decorators";

export default Ember.View.extend(LoadMore, UrlRefresh, {
  eyelineSelector: '.topic-list-item',

  actions: {
    loadMore() {
      const self = this;
      Discourse.notifyTitle(0);
      this.get('controller').loadMoreTopics().then(hasMoreResults => {
        Ember.run.schedule('afterRender', () => self.saveScrollPosition());
        if (!hasMoreResults) {
          this.get('eyeline').flushRest();
        } else if ($(window).height() >= $(document).height()) {
          this.send("loadMore");
        }
      });
    }
  },

  @on("didInsertElement")
  @observes("controller.model")
  _readjustScrollPosition() {
    const scrollTo = this.session.get('topicListScrollPosition');
    if (scrollTo && scrollTo >= 0) {
      Ember.run.schedule('afterRender', () => $(window).scrollTop(scrollTo + 1));
    } else {
      this.loadMoreUnlessFull();
    }
  },

  @observes("controller.topicTrackingState.incomingCount")
  _updateTitle() {
    Discourse.notifyTitle(this.get('controller.topicTrackingState.incomingCount'));
  },

  // Remember where we were scrolled to
  saveScrollPosition() {
    this.session.set('topicListScrollPosition', $(window).scrollTop());
  },

  // When the topic list is scrolled
  scrolled() {
    this._super();
    this.saveScrollPosition();
  }
});
