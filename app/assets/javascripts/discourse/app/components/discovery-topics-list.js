import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import $ from "jquery";
import LoadMore from "discourse/mixins/load-more";
import UrlRefresh from "discourse/mixins/url-refresh";
import { observes, on } from "discourse-common/utils/decorators";

const _beforeLoadMoreCallbacks = [];
export function addBeforeLoadMoreCallback(fn) {
  _beforeLoadMoreCallbacks.push(fn);
}
export function resetBeforeLoadMoreCallbacks() {
  _beforeLoadMoreCallbacks.clear();
}

export default Component.extend(UrlRefresh, LoadMore, {
  classNames: ["contents"],
  eyelineSelector: ".topic-list-item",
  documentTitle: service(),
  appEvents: service(),

  @on("didInsertElement")
  _monitorTrackingState() {
    this.stateChangeCallbackId = this.topicTrackingState.onStateChange(() =>
      this._updateTrackingTopics()
    );

    this.appEvents.on("discovery-topics-list:loadMore", this, "loadMore");
  },

  @on("willDestroyElement")
  _removeTrackingStateChangeMonitor() {
    if (this.stateChangeCallbackId) {
      this.topicTrackingState.offStateChange(this.stateChangeCallbackId);
    }

    this.appEvents.off("discovery-topics-list:loadMore", this, "loadMore");
  },

  _updateTrackingTopics() {
    this.topicTrackingState.updateTopics(this.model.topics);
  },

  @observes("incomingCount")
  _updateTitle() {
    this.documentTitle.updateContextCount(this.incomingCount);
  },

  @action
  loadMore() {
    if (
      _beforeLoadMoreCallbacks.length &&
      !_beforeLoadMoreCallbacks.some((fn) => fn(this))
    ) {
      // Return early if any callbacks return false, short-circuiting the default loading more logic
      return;
    }

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
      if (moreTopicsUrl && $(window).height() >= $(document).height()) {
        this.send("loadMore");
      }
      if (this.loadingComplete) {
        this.loadingComplete();
      }
    });
  },
});
