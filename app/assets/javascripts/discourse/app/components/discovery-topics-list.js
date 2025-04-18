import Component from "@ember/component";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";

@classNames("contents")
export default class DiscoveryTopicsList extends Component {
  @service appEvents;
  @service documentTitle;

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
}
