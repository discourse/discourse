import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import $ from "jquery";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import LoadMore from "discourse/mixins/load-more";

@classNames("contents")
export default class DiscoveryTopicsList extends Component.extend(LoadMore) {
  @service appEvents;
  @service documentTitle;
  eyelineSelector = ".topic-list-item";

  @on("didInsertElement")
  _monitorTrackingState() {
    this.stateChangeCallbackId = this.topicTrackingState.onStateChange(() =>
      this._updateTrackingTopics()
    );
  }

  @on("willDestroyElement")
  _removeTrackingStateChangeMonitor() {
    if (this.stateChangeCallbackId) {
      this.topicTrackingState.offStateChange(this.stateChangeCallbackId);
    }
  }

  _updateTrackingTopics() {
    this.topicTrackingState.updateTopics(this.model.topics);
  }

  @observes("incomingCount")
  _updateTitle() {
    this.documentTitle.updateContextCount(this.incomingCount);
  }

  @action
  loadMore() {
    applyBehaviorTransformer(
      "discovery-topic-list-load-more",
      () => {
        this.documentTitle.updateContextCount(0);
        return this.model
          .loadMore()
          .then(({ moreTopicsUrl, newTopics } = {}) => {
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
      { model: this.model }
    );
  }
}
