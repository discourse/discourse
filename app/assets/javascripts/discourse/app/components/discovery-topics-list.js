import { observes, on } from "discourse-common/utils/decorators";
import { schedule, scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
import LoadMore from "discourse/mixins/load-more";
import UrlRefresh from "discourse/mixins/url-refresh";
import { inject as service } from "@ember/service";

export default Component.extend(UrlRefresh, LoadMore, {
  classNames: ["contents"],
  eyelineSelector: ".topic-list-item",
  documentTitle: service(),

  @on("didInsertElement")
  @observes("model")
  _readjustScrollPosition() {
    const scrollTo = this.session.get("topicListScrollPosition");
    if (scrollTo && scrollTo >= 0) {
      schedule("afterRender", () => $(window).scrollTop(scrollTo + 1));
    } else {
      scheduleOnce("afterRender", this, this.loadMoreUnlessFull);
    }
  },

  @on("didInsertElement")
  _monitorTrackingState() {
    this.topicTrackingState.onStateChange(() => this._updateTrackingTopics());
  },

  @on("willDestroyElement")
  _removeTrackingStateChangeMonitor() {
    this.topicTrackingState.offStateChange(this.stateChangeCallbackId);
  },

  _updateTrackingTopics() {
    this.topicTrackingState.updateTopics(this.model.topics);
  },

  @observes("incomingCount")
  _updateTitle() {
    this.documentTitle.updateContextCount(this.incomingCount);
  },

  saveScrollPosition() {
    this.session.set("topicListScrollPosition", $(window).scrollTop());
  },

  actions: {
    loadMore() {
      this.documentTitle.updateContextCount(0);
      this.model.loadMore().then(({ moreTopicsUrl, newTopics } = {}) => {
        if (
          newTopics &&
          newTopics.length &&
          this.autoAddTopicsToBulkSelect &&
          this.bulkSelectEnabled
        ) {
          this.addTopicsToBulkSelect(newTopics);
        }
        schedule("afterRender", () => this.saveScrollPosition());
        if (moreTopicsUrl && $(window).height() >= $(document).height()) {
          this.send("loadMore");
        }
        if (this.loadingComplete) {
          this.loadingComplete();
        }
      });
    },
  },
});
