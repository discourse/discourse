import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { action } from "@ember/object";
import { scheduleOnce } from "@ember/runloop";
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
  @tracked observer;
  eyelineSelector = ".topic-list-item:last-of-type";

  @on("didInsertElement")
  _monitorTrackingState() {
    this.stateChangeCallbackId = this.topicTrackingState.onStateChange(() =>
      this._updateTrackingTopics()
    );
  }

  @on("didInsertElement")
  _setupIntersectionObserver() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          const bcr = entry.boundingClientRect;
          const isBottomVisible = bcr.bottom < window.innerHeight && bcr.bottom;
          if (isBottomVisible) {
            this.loadMore();
            scheduleOnce("afterRender", this, this._observeLastTopic);
          }
        });
      },
      {
        root: document.querySelector("#main-outlet"),
        rootMargin: "0px",
        threshold: 1.0,
      }
    );

    scheduleOnce("afterRender", this, this._observeLastTopic);
  }

  @on("willDestroyElement")
  _removeTrackingStateChangeMonitor() {
    if (this.stateChangeCallbackId) {
      this.topicTrackingState.offStateChange(this.stateChangeCallbackId);
    }
  }

  @on("willDestroyElement")
  _cleanupIntersectionObserver() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  _observeLastTopic() {
    const lastTopic = this.element.querySelector(this.eyelineSelector);

    if (lastTopic) {
      this.observer.observe(lastTopic);
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
