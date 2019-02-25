import { observes } from "ember-addons/ember-computed-decorators";
import showModal from "discourse/lib/show-modal";
import PanEvents, {
  SWIPE_VELOCITY,
  SWIPE_DISTANCE_THRESHOLD,
  SWIPE_VELOCITY_THRESHOLD
} from "discourse/mixins/pan-events";

export default Ember.Component.extend(PanEvents, {
  composerOpen: null,
  info: null,
  isPanning: false,

  init() {
    this._super(...arguments);
    this.set("info", Ember.Object.create());
  },

  _performCheckSize() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    let info = this.get("info");

    if (info.get("topicProgressExpanded")) {
      info.setProperties({
        renderTimeline: true,
        renderAdminMenuButton: true
      });
    } else {
      let renderTimeline = !this.site.mobileView;

      if (renderTimeline) {
        const width = $(window).width();
        let height = $(window).height();

        if (this.get("composerOpen")) {
          height -= $("#reply-control").height();
        }

        renderTimeline = width > 924 && height > 520;
      }

      info.setProperties({
        renderTimeline,
        renderAdminMenuButton: !renderTimeline
      });
    }
  },

  _checkSize() {
    Ember.run.scheduleOnce("afterRender", this, this._performCheckSize);
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
    // we need to do the check after animation is done
    Ember.run.later(() => this._checkSize(), 500);
  },

  composerClosed() {
    this.set("composerOpen", false);
    this._checkSize();
  },

  _collapseFullscreen() {
    if (this.get("info.topicProgressExpanded")) {
      $(".timeline-fullscreen").removeClass("show");
      Ember.run.later(() => {
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
        topic: this.get("topic"),
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
      Ember.run.later(() => this._handlePanDone(offset, event), 20);
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
      this.appEvents.on("composer:will-open", this, this.composerOpened);
      this.appEvents.on("composer:will-close", this, this.composerClosed);
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
      this.appEvents.off("composer:will-open", this, this.composerOpened);
      this.appEvents.off("composer:will-close", this, this.composerClosed);
      $("#reply-control").off("div-resized.discourse-topic-navigation");
    }
  }
});
