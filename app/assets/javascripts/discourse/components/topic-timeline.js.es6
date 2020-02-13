import { next } from "@ember/runloop";
import MountWidget from "discourse/components/mount-widget";
import Docking from "discourse/mixins/docking";
import { observes } from "discourse-common/utils/decorators";
import optionalService from "discourse/lib/optional-service";

const headerPadding = () => {
  let topPadding = parseInt($("#main-outlet").css("padding-top"), 10) + 3;
  const iPadNavHeight = $(".footer-nav-ipad .footer-nav").height();
  if (iPadNavHeight) {
    topPadding += iPadNavHeight;
  }
  return topPadding;
};

export default MountWidget.extend(Docking, {
  adminTools: optionalService(),
  widget: "topic-timeline-container",
  dockBottom: null,
  dockAt: null,

  buildArgs() {
    let attrs = {
      topic: this.topic,
      notificationLevel: this.notificationLevel,
      topicTrackingState: this.topicTrackingState,
      enteredIndex: this.enteredIndex,
      dockAt: this.dockAt,
      dockBottom: this.dockBottom,
      mobileView: this.get("site.mobileView")
    };

    let event = this.prevEvent;
    if (event) {
      attrs.enteredIndex = event.postIndex - 1;
    }

    if (this.fullscreen) {
      attrs.fullScreen = true;
      attrs.addShowClass = this.addShowClass;
    } else {
      attrs.top = this.dockAt || headerPadding();
    }

    return attrs;
  },

  @observes("topic.highest_post_number", "loading")
  newPostAdded() {
    this.queueRerender(() => this.queueDockCheck());
  },

  @observes("topic.details.notification_level")
  _queueRerender() {
    this.queueRerender();
  },

  dockCheck(info) {
    const mainOffset = $("#main").offset();
    const offsetTop = mainOffset ? mainOffset.top : 0;
    const topicTop = $(".container.posts").offset().top - offsetTop;
    const topicBottom =
      $("#topic-bottom").offset().top - $("#main-outlet").offset().top;
    const timeline = this.element.querySelector(".timeline-container");
    const timelineHeight = (timeline && timeline.offsetHeight) || 400;
    const footerHeight = $(".timeline-footer-controls").outerHeight(true) || 0;

    const prev = this.dockAt;
    const posTop = headerPadding() + info.offset();
    const pos = posTop + timelineHeight;

    this.dockBottom = false;
    if (posTop < topicTop) {
      this.dockAt = parseInt(topicTop, 10);
    } else if (pos > topicBottom + footerHeight) {
      this.dockAt = parseInt(topicBottom - timelineHeight + footerHeight, 10);
      this.dockBottom = true;
      if (this.dockAt < 0) {
        this.dockAt = 0;
      }
    } else {
      this.dockAt = null;
      this.fastDockAt = parseInt(
        topicBottom - timelineHeight + footerHeight - offsetTop,
        10
      );
    }

    if (this.dockAt !== prev) {
      this.queueRerender();
    }
  },

  didInsertElement() {
    this._super(...arguments);

    if (this.fullscreen && !this.addShowClass) {
      next(() => {
        this.set("addShowClass", true);
        this.queueRerender();
      });
    }

    this.dispatch("topic:current-post-scrolled", "timeline-scrollarea");
    this.dispatch("topic:toggle-actions", "topic-admin-menu-button");
    if (!this.site.mobileView) {
      this.appEvents.on("composer:opened", this, this.queueRerender);
      this.appEvents.on("composer:resized", this, this.queueRerender);
      this.appEvents.on("composer:closed", this, this.queueRerender);
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (!this.site.mobileView) {
      this.appEvents.off("composer:opened", this, this.queueRerender);
      this.appEvents.off("composer:resized", this, this.queueRerender);
      this.appEvents.off("composer:closed", this, this.queueRerender);
    }
  }
});
