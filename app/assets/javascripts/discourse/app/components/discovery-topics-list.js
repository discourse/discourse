import { observes, on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import LoadMore from "discourse/mixins/load-more";
import { inject as service } from "@ember/service";

export default Component.extend(LoadMore, {
  classNames: ["contents"],
  eyelineSelector: ".topic-list-item",
  documentTitle: service(),

  @on("didInsertElement")
  _monitorTrackingState() {
    this.stateChangeCallbackId = this.topicTrackingState.onStateChange(() =>
      this._updateTrackingTopics()
    );
  },

  @on("willDestroyElement")
  _removeTrackingStateChangeMonitor() {
    if (this.stateChangeCallbackId) {
      this.topicTrackingState.offStateChange(this.stateChangeCallbackId);
    }
  },

  _updateTrackingTopics() {
    this.topicTrackingState.updateTopics(this.model.topics);
  },

  @observes("incomingCount")
  _updateTitle() {
    this.documentTitle.updateContextCount(this.incomingCount);
  },

  actions: {
    loadMore() {
      this.documentTitle.updateContextCount(0);
      this.model.loadMore().then(({ moreTopicsUrl, newTopics } = {}) => {
        if (
          newTopics &&
          newTopics.length &&
          this.bulkSelectHelper?.bulkSelectEnabled
        ) {
          this.bulkSelectHelper.addTopics(newTopics);
        }
        if (moreTopicsUrl && $(window).height() >= $(document).height()) {
          this.send("loadMore");
        }
      });
    },
  },
});
