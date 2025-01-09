import Component from "@ember/component";
import EmberObject from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import $ from "jquery";
import { headerOffset } from "discourse/lib/offset-calculator";
import SwipeEvents from "discourse/lib/swipe-events";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";
import JumpToPost from "./modal/jump-to-post";

const MIN_WIDTH_TIMELINE = 925;
const MIN_HEIGHT_TIMELINE = 325;

@classNameBindings(
  "info.topicProgressExpanded:topic-progress-expanded",
  "info.renderTimeline:with-timeline",
  "info.withTopicProgress:with-topic-progress"
)
export default class TopicNavigation extends Component {
  @service modal;

  composerOpen = null;
  info = EmberObject.create();
  canRender = true;
  _lastTopicId = null;
  _swipeEvents = null;

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);
    if (this._lastTopicId !== this.topic.id) {
      this._lastTopicId = this.topic.id;
      this.set("canRender", false);
      next(() => {
        this.set("canRender", true);
        this._performCheckSize();
      });
    }
  }

  _performCheckSize() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.info.topicProgressExpanded) {
      this.info.set("renderTimeline", true);
    } else if (this.site.mobileView) {
      this.info.set("renderTimeline", false);
    } else {
      const composerHeight =
        document.querySelector("#reply-control")?.offsetHeight || 0;
      const verticalSpace =
        window.innerHeight - composerHeight - headerOffset();

      this.info.set(
        "renderTimeline",
        this.mediaQuery.matches && verticalSpace > MIN_HEIGHT_TIMELINE
      );
    }

    this.info.set(
      "withTopicProgress",
      !this.info.renderTimeline && this.topic.posts_count > 1
    );
  }

  @bind
  _checkSize() {
    discourseDebounce(this, this._performCheckSize, 200, true);
  }

  // we need to store this so topic progress has something to init with
  _topicScrolled(event) {
    this.set("info.prevEvent", event);
  }

  @observes("info.topicProgressExpanded")
  _expanded() {
    if (this.get("info.topicProgressExpanded")) {
      $(window).on("click.hide-fullscreen", (e) => {
        let $target = $(e.target);
        let $parents = $target.parents();
        if (
          !$target.is(".widget-button") &&
          !$parents.is(".widget-button") &&
          !$parents.is("#discourse-modal") &&
          !$target.is("#discourse-modal") &&
          ($target.is(".topic-timeline") ||
            !$parents.is("#topic-progress-wrapper")) &&
          !$parents.is(".timeline-open-jump-to-post-prompt-btn") &&
          !$target.is(".timeline-open-jump-to-post-prompt-btn")
        ) {
          this._collapseFullscreen();
        }
      });
    } else {
      $(window).off("click.hide-fullscreen");
    }
    this._checkSize();
  }

  composerOpened() {
    this.set("composerOpen", true);
    this._checkSize();
  }

  composerClosed() {
    this.set("composerOpen", false);
    this._checkSize();
  }

  _collapseFullscreen(postId, delay = 500) {
    if (this.get("info.topicProgressExpanded")) {
      $(".timeline-fullscreen").removeClass("show");
      discourseLater(() => {
        if (!this.element || this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("info.topicProgressExpanded", false);
        this._checkSize();
      }, delay);
    }
  }

  keyboardTrigger(e) {
    if (e.type === "jump") {
      this.modal.show(JumpToPost, {
        model: {
          topic: this.topic,
          jumpToIndex: this.jumpToIndex,
          jumpToDate: this.jumpToDate,
        },
      });
    }
  }

  @bind
  onSwipeStart(event) {
    const e = event.detail;
    const target = e.originalEvent.target;

    if (
      target.classList.contains("docked") ||
      !target.closest(".timeline-container")
    ) {
      event.preventDefault();
      return;
    }

    e.originalEvent.preventDefault();
    const centeredElement = document.elementFromPoint(e.center.x, e.center.y);
    if (centeredElement.closest(".timeline-scrollarea-wrapper")) {
      event.preventDefault();
    } else if (e.direction === "up" || e.direction === "down") {
      this.movingElement = document.querySelector(".timeline-container");
    }
  }

  @bind
  onSwipeCancel() {
    let durationMs = this._swipeEvents.getMaxAnimationTimeMs();
    const timelineContainer = document.querySelector(".timeline-container");
    timelineContainer.animate([{ transform: `translate3d(0, 0, 0)` }], {
      duration: durationMs,
      fill: "forwards",
      easing: "ease-out",
    });
  }

  @bind
  onSwipeEnd(event) {
    const e = event.detail;
    const timelineContainer = document.querySelector(".timeline-container");
    const maxOffset = timelineContainer.offsetHeight;

    let durationMs = this._swipeEvents.getMaxAnimationTimeMs();
    if (this._swipeEvents.shouldCloseMenu(e, "bottom")) {
      const distancePx = maxOffset - this.pxClosed;
      durationMs = this._swipeEvents.getMaxAnimationTimeMs(
        distancePx / Math.abs(e.velocityY)
      );
      timelineContainer
        .animate([{ transform: `translate3d(0, ${maxOffset}px, 0)` }], {
          duration: durationMs,
          fill: "forwards",
        })
        .finished.then(() => this._collapseFullscreen(null, 0));
    } else {
      const distancePx = this.pxClosed;
      durationMs = this._swipeEvents.getMaxAnimationTimeMs(
        distancePx / Math.abs(e.velocityY)
      );
      timelineContainer.animate([{ transform: `translate3d(0, 0, 0)` }], {
        duration: durationMs,
        fill: "forwards",
        easing: "ease-out",
      });
    }
  }

  @bind
  onSwipe(event) {
    const e = event.detail;
    e.originalEvent.preventDefault();
    this.pxClosed = Math.max(0, e.deltaY);

    this.movingElement.animate(
      [{ transform: `translate3d(0, ${this.pxClosed}px, 0)` }],
      { fill: "forwards" }
    );
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this._lastTopicId = this.topic.id;

    this.appEvents
      .on("topic:current-post-scrolled", this, this._topicScrolled)
      .on("topic:jump-to-post", this, this._collapseFullscreen)
      .on("topic:keyboard-trigger", this, this.keyboardTrigger);

    if (this.site.desktopView) {
      this.mediaQuery = matchMedia(`(min-width: ${MIN_WIDTH_TIMELINE}px)`);
      this.mediaQuery.addEventListener("change", this._checkSize);
      this.appEvents.on("composer:opened", this, this.composerOpened);
      this.appEvents.on("composer:resize-ended", this, this.composerOpened);
      this.appEvents.on("composer:closed", this, this.composerClosed);
      $("#reply-control").on("div-resized", this._checkSize);
    }

    this._checkSize();
    this._swipeEvents = new SwipeEvents(this.element);
    if (this.site.mobileView) {
      this._swipeEvents.addTouchListeners();
      this.element.addEventListener("swipestart", this.onSwipeStart);
      this.element.addEventListener("swipeend", this.onSwipeEnd);
      this.element.addEventListener("swipecancel", this.onSwipeCancel);
      this.element.addEventListener("swipe", this.onSwipe);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.appEvents
      .off("topic:current-post-scrolled", this, this._topicScrolled)
      .off("topic:jump-to-post", this, this._collapseFullscreen)
      .off("topic:keyboard-trigger", this, this.keyboardTrigger);

    $(window).off("click.hide-fullscreen");

    if (this.site.desktopView) {
      this.mediaQuery.removeEventListener("change", this._checkSize);
      this.appEvents.off("composer:opened", this, this.composerOpened);
      this.appEvents.off("composer:resize-ended", this, this.composerOpened);
      this.appEvents.off("composer:closed", this, this.composerClosed);
      $("#reply-control").off("div-resized", this._checkSize);
    }
    if (this.site.mobileView) {
      this.element.removeEventListener("swipestart", this.onSwipeStart);
      this.element.removeEventListener("swipeend", this.onSwipeEnd);
      this.element.removeEventListener("swipecancel", this.onSwipeCancel);
      this.element.removeEventListener("swipe", this.onSwipe);
      this._swipeEvents.removeTouchListeners();
    }
  }
}
