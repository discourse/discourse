import Docking from "discourse/mixins/docking";
import MountWidget from "discourse/components/mount-widget";
import { headerOffset } from "discourse/lib/offset-calculator";
import { next } from "@ember/runloop";
import { observes } from "discourse-common/utils/decorators";
import optionalService from "discourse/lib/optional-service";

export default MountWidget.extend(Docking, {
  adminTools: optionalService(),
  widget: "topic-timeline-container",
  dockBottom: null,
  dockAt: null,
  intersectionObserver: null,

  buildArgs() {
    let attrs = {
      topic: this.topic,
      notificationLevel: this.notificationLevel,
      topicTrackingState: this.topicTrackingState,
      enteredIndex: this.enteredIndex,
      dockAt: this.dockAt,
      dockBottom: this.dockBottom,
      mobileView: this.get("site.mobileView"),
    };

    let event = this.prevEvent;
    if (event) {
      attrs.enteredIndex = event.postIndex - 1;
    }

    if (this.fullscreen) {
      attrs.fullScreen = true;
      attrs.addShowClass = this.addShowClass;
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

  dockCheck() {
    const timeline = this.element.querySelector(".timeline-container");
    const timelineHeight = (timeline && timeline.offsetHeight) || 400;

    const prev = this.dockAt;
    const posTop = headerOffset() + window.pageYOffset;
    const pos = posTop + timelineHeight;

    this.dockBottom = false;
    if (posTop < this.topicTop) {
      this.dockAt = parseInt(this.topicTop, 10);
    } else if (pos > this.topicBottom) {
      this.dockAt = parseInt(this.topicBottom - timelineHeight, 10);
      this.dockBottom = true;
      if (this.dockAt < 0) {
        this.dockAt = 0;
      }
    } else {
      this.dockAt = null;
      this.fastDockAt = parseInt(this.topicBottom - timelineHeight, 10);
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

    this.dispatch(
      "topic:current-post-scrolled",
      () => `timeline-scrollarea-${this.topic.id}`
    );
    this.dispatch("topic:toggle-actions", "topic-admin-menu-button");
    if (!this.site.mobileView) {
      this.appEvents.on("composer:opened", this, this.queueRerender);
      this.appEvents.on("composer:resized", this, this.queueRerender);
      this.appEvents.on("composer:closed", this, this.queueRerender);
      if ("IntersectionObserver" in window) {
        this.intersectionObserver = new IntersectionObserver((entries) => {
          for (const entry of entries) {
            const bounds = entry.boundingClientRect;

            if (entry.target.id === "topic-bottom") {
              this.set("topicBottom", bounds.y + window.scrollY);
            } else {
              this.set("topicTop", bounds.y + window.scrollY);
            }
          }
        });

        const elements = [
          document.querySelector(".container.posts"),
          document.querySelector("#topic-bottom"),
        ];

        for (let i = 0; i < elements.length; i++) {
          this.intersectionObserver.observe(elements[i]);
        }
      }
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (!this.site.mobileView) {
      this.appEvents.off("composer:opened", this, this.queueRerender);
      this.appEvents.off("composer:resized", this, this.queueRerender);
      this.appEvents.off("composer:closed", this, this.queueRerender);
      if ("IntersectionObserver" in window) {
        this.intersectionObserver?.disconnect();
        this.intersectionObserver = null;
      }
    }
  },
});
