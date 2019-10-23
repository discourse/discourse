import Component from "@ember/component";
import { on, observes } from "ember-addons/ember-computed-decorators";
import LoadMore from "discourse/mixins/load-more";
import UrlRefresh from "discourse/mixins/url-refresh";

const DiscoveryTopicsListComponent = Component.extend(UrlRefresh, LoadMore, {
  classNames: ["contents"],
  eyelineSelector: ".topic-list-item",

  @on("didInsertElement")
  @observes("model")
  _readjustScrollPosition() {
    const scrollTo = this.session.get("topicListScrollPosition");
    if (scrollTo && scrollTo >= 0) {
      Ember.run.schedule("afterRender", () =>
        $(window).scrollTop(scrollTo + 1)
      );
    } else {
      Ember.run.scheduleOnce("afterRender", this, this.loadMoreUnlessFull);
    }
  },

  @observes("topicTrackingState.states")
  _updateTopics() {
    this.topicTrackingState.updateTopics(this.model.topics);
  },

  @observes("incomingCount")
  _updateTitle() {
    Discourse.updateContextCount(this.incomingCount);
  },

  saveScrollPosition() {
    this.session.set("topicListScrollPosition", $(window).scrollTop());
  },

  actions: {
    loadMore() {
      Discourse.updateContextCount(0);
      this.model.loadMore().then(hasMoreResults => {
        Ember.run.schedule("afterRender", () => this.saveScrollPosition());
        if (!hasMoreResults) {
          this.eyeline.flushRest();
        } else if ($(window).height() >= $(document).height()) {
          this.send("loadMore");
        }
      });
    }
  }
});

export default DiscoveryTopicsListComponent;
