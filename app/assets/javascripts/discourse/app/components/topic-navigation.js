import PanEvents, {
  SWIPE_DISTANCE_THRESHOLD,
  SWIPE_VELOCITY_THRESHOLD,
} from "discourse/mixins/pan-events";
import Component from "@ember/component";
import EmberObject from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { headerOffset } from "discourse/lib/offset-calculator";
import { later, next } from "@ember/runloop";
import { observes } from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";

const MIN_WIDTH_TIMELINE = 924,
  MIN_HEIGHT_TIMELINE = 325;

export default Component.extend(PanEvents, {
  classNameBindings: [
    "info.topicProgressExpanded:topic-progress-expanded",
    "info.renderTimeline:with-timeline:with-topic-progress",
  ],
  composerOpen: null,
  info: null,
  isPanning: false,
  canRender: true,
  _lastTopicId: null,

  init() {
    this._super(...arguments);
    this.set("info", EmberObject.create());
  },

  didUpdateAttrs() {
    this._super(...arguments);
    if (this._lastTopicId !== this.topic.id) {
      this._lastTopicId = this.topic.id;
      this.set("canRender", false);
      next(() => this.set("canRender", true));
    }
  },

  _performCheckSize() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    let info = this.info;

    if (info.get("topicProgressExpanded")) {
      info.set("renderTimeline", true);
    } else {
      let renderTimeline = !this.site.mobileView;

      if (renderTimeline) {
        const composer = document.getElementById("reply-control");

        if (composer) {
          renderTimeline =
            window.innerWidth > MIN_WIDTH_TIMELINE &&
            window.innerHeight - composer.offsetHeight - headerOffset() >
              MIN_HEIGHT_TIMELINE;
        }
      }

      info.set("renderTimeline", renderTimeline);
    }
  },

  _checkSize() {
    discourseDebounce(this, this._performCheckSize, 300, true);
  },

  // we need to store this so topic progress has something to init with
  _topicScrolled(event) {
    this.set("info.prevEvent", event);
  },

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
          !$parents.is(".modal-footer") &&
          ($target.is(".topic-timeline") ||
            !$parents.is("#topic-progress-wrapper"))
        ) {
          this._collapseFullscreen();
        }
      });
    } else {
      $(window).off("click.hide-fullscreen");
    }
    this._checkSize();
  },

  composerOpened() {
    this.set("composerOpen", true);
    this._checkSize();
  },

  composerClosed() {
    this.set("composerOpen", false);
    this._checkSize();
  },

  _collapseFullscreen() {
    if (this.get("info.topicProgressExpanded")) {
      $(".timeline-fullscreen").removeClass("show");
      later(() => {
        if (!this.element || this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("info.topicProgressExpanded", false);
        this._checkSize();
      }, 500);
    }
  },

  keyboardTrigger(e) {
    if (e.type === "jump") {
      const controller = showModal("jump-to-post", {
        modalClass: "jump-to-post-modal",
      });
      controller.setProperties({
        topic: this.topic,
        jumpToIndex: this.attrs.jumpToIndex,
        jumpToDate: this.attrs.jumpToDate,
      });
    }
  },

  _handlePanDone(offset, event) {
    const $timelineContainer = $(".timeline-container");
    const maxOffset = parseInt($timelineContainer.css("height"), 10);

    $timelineContainer.addClass("animate");
    if (this._shouldPanClose(event)) {
      $timelineContainer.css("--offset", `${maxOffset}px`);
      later(() => {
        this._collapseFullscreen();
        $timelineContainer.removeClass("animate");
      }, 200);
    } else {
      $timelineContainer.css("--offset", 0);
      later(() => {
        $timelineContainer.removeClass("animate");
      }, 200);
    }
  },

  _shouldPanClose(e) {
    return (
      (e.deltaY > SWIPE_DISTANCE_THRESHOLD &&
        e.velocityY > -SWIPE_VELOCITY_THRESHOLD) ||
      e.velocityY > SWIPE_VELOCITY_THRESHOLD
    );
  },

  panStart(e) {
    if (e.originalEvent.target.classList.contains("docked")) {
      return;
    }

    e.originalEvent.preventDefault();
    const center = e.center;
    const $centeredElement = $(document.elementFromPoint(center.x, center.y));
    if ($centeredElement.parents(".timeline-scrollarea-wrapper").length) {
      this.isPanning = false;
    } else if (e.direction === "up" || e.direction === "down") {
      this.isPanning = true;
    }
  },

  panEnd(e) {
    if (!this.isPanning) {
      return;
    }
    e.originalEvent.preventDefault();
    this.isPanning = false;
    this._handlePanDone(e.deltaY, e);
  },

  panMove(e) {
    if (!this.isPanning) {
      return;
    }
    e.originalEvent.preventDefault();
    $(".timeline-container").css("--offset", `${Math.max(0, e.deltaY)}px`);
  },

  didInsertElement() {
    this._super(...arguments);

    this._lastTopicId = this.topic.id;

    this.appEvents
      .on("topic:current-post-scrolled", this, this._topicScrolled)
      .on("topic:jump-to-post", this, this._collapseFullscreen)
      .on("topic:keyboard-trigger", this, this.keyboardTrigger);

    if (!this.site.mobileView) {
      $(window).on("resize.discourse-topic-navigation", () =>
        this._checkSize()
      );
      this.appEvents.on("composer:opened", this, this.composerOpened);
      this.appEvents.on("composer:resize-ended", this, this.composerOpened);
      this.appEvents.on("composer:closed", this, this.composerClosed);
      $("#reply-control").on("div-resized.discourse-topic-navigation", () =>
        this._checkSize()
      );
    }

    this._checkSize();
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents
      .off("topic:current-post-scrolled", this, this._topicScrolled)
      .off("topic:jump-to-post", this, this._collapseFullscreen)
      .off("topic:keyboard-trigger", this, this.keyboardTrigger);

    $(window).off("click.hide-fullscreen");

    if (!this.site.mobileView) {
      $(window).off("resize.discourse-topic-navigation");
      this.appEvents.off("composer:opened", this, this.composerOpened);
      this.appEvents.off("composer:resize-ended", this, this.composerOpened);
      this.appEvents.off("composer:closed", this, this.composerClosed);
      $("#reply-control").off("div-resized.discourse-topic-navigation");
    }
  },
});
