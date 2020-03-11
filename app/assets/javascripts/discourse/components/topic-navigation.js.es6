import EmberObject from "@ember/object";
import { debounce, later } from "@ember/runloop";
import Component from "@ember/component";
import { observes } from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import PanEvents, {
  SWIPE_VELOCITY,
  SWIPE_DISTANCE_THRESHOLD,
  SWIPE_VELOCITY_THRESHOLD
} from "discourse/mixins/pan-events";

const MIN_WIDTH_TIMELINE = 924;

export default Component.extend(PanEvents, {
  composerOpen: null,
  info: null,
  isPanning: false,

  init() {
    this._super(...arguments);
    this.set("info", EmberObject.create());
  },

  _performCheckSize() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    let info = this.info;

    if (info.get("topicProgressExpanded")) {
      info.setProperties({
        renderTimeline: true,
        renderAdminMenuButton: true
      });
    } else {
      let renderTimeline = !this.site.mobileView;

      if (renderTimeline) {
        const width = window.innerWidth,
          composer = document.getElementById("reply-control"),
          timelineContainer = document.querySelector(".timeline-container"),
          headerContainer = document.querySelector(".d-header"),
          headerHeight = (headerContainer && headerContainer.offsetHeight) || 0;

        if (timelineContainer && composer) {
          renderTimeline =
            width > MIN_WIDTH_TIMELINE &&
            window.innerHeight - composer.offsetHeight - headerHeight >
              timelineContainer.offsetHeight;
        }
      }

      info.setProperties({
        renderTimeline,
        renderAdminMenuButton: !renderTimeline
      });
    }
  },

  _checkSize() {
    debounce(this, this._performCheckSize, 300, true);
  },

  // we need to store this so topic progress has something to init with
  _topicScrolled(event) {
    this.set("info.prevEvent", event);
  },

  @observes("info.topicProgressExpanded")
  _expanded() {
    if (this.get("info.topicProgressExpanded")) {
      $(window).on("click.hide-fullscreen", e => {
        let $target = $(e.target);
        let $parents = $target.parents();
        if (
          !$target.is(".widget-button") &&
          !$parents.is(".widget-button") &&
          !$parents.is(".dropdown-menu") &&
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
        modalClass: "jump-to-post-modal"
      });
      controller.setProperties({
        topic: this.topic,
        jumpToIndex: this.attrs.jumpToIndex,
        jumpToDate: this.attrs.jumpToDate
      });
    }
  },

  _handlePanDone(offset, event) {
    const $timelineContainer = $(".timeline-container");
    const maxOffset = parseInt($timelineContainer.css("height"), 10);

    this._shouldPanClose(event)
      ? (offset += SWIPE_VELOCITY)
      : (offset -= SWIPE_VELOCITY);

    $timelineContainer.css("bottom", -offset);
    if (offset > maxOffset) {
      this._collapseFullscreen();
    } else if (offset <= 0) {
      $timelineContainer.css("bottom", "");
    } else {
      later(() => this._handlePanDone(offset, event), 20);
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
    $(".timeline-container").css("bottom", Math.min(0, -e.deltaY));
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents
      .on("topic:current-post-scrolled", this, this._topicScrolled)
      .on("topic:jump-to-post", this, this._collapseFullscreen)
      .on("topic:keyboard-trigger", this, this.keyboardTrigger);

    if (!this.site.mobileView) {
      $(window).on("resize.discourse-topic-navigation", () =>
        this._checkSize()
      );
      this.appEvents.on("composer:opened", this, this.composerOpened);
      this.appEvents.on("composer:resized", this, this.composerOpened);
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
      this.appEvents.off("composer:resized", this, this.composerOpened);
      this.appEvents.off("composer:closed", this, this.composerClosed);
      $("#reply-control").off("div-resized.discourse-topic-navigation");
    }
  }
});
