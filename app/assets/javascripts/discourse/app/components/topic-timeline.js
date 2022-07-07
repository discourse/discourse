import GlimmerComponent from "discourse/components/glimmer";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";

import Docking from "discourse/mixins/docking";
import { headerOffset } from "discourse/lib/offset-calculator";
import { observes } from "discourse-common/utils/decorators";
import optionalService from "discourse/lib/optional-service";

export default class TopicTimeline extends GlimmerComponent {
  @tracked prevEvent;

  mobileView = this.site.mobileView;
  intersectionObserver = null;
  dockAt = null;
  dockBottom = null;
  adminTools = optionalService();

  constructor() {
    super(...arguments);
  }

  @action
  updateEnteredIndex(prevEvent) {
    this.prevEvent = prevEvent;
    if (prevEvent) {
      this.enteredIndex = prevEvent.postIndex - 1;
    }
  }

  @observes("topic.highest_post_number", "loading")
  newPostAdded() {
    // not sure if this is the play
    Docking.queueDockCheck();
  }

  @observes("topic.details.notification_level")
  updateNotificationLevel() {
    // update value here
  }

  @bind
  dockCheck() {
    const timeline = this.element.querySelector(".timeline-container");
    const timelineHeight = (timeline && timeline.offsetHeight) || 400;

    const prev = this.args.dockAt;
    const posTop = headerOffset() + window.pageYOffset;
    const pos = posTop + timelineHeight;

    this.args.dockBottom = false;
    if (posTop < this.topicTop) {
      this.args.dockAt = parseInt(this.topicTop, 10);
    } else if (pos > this.topicBottom) {
      this.args.dockAt = parseInt(this.topicBottom - timelineHeight, 10);
      this.args.dockBottom = true;
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
  }

  didInsert() {
    this.dispatch(
      "topic:current-post-scrolled",
      () => `timeline-scrollarea-${this.args.topic.id}`
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
  }

  willDestroy() {
    if (!this.site.mobileView) {
      this.appEvents.off("composer:opened", this, this.queueRerender);
      this.appEvents.off("composer:resized", this, this.queueRerender);
      this.appEvents.off("composer:closed", this, this.queueRerender);
      if ("IntersectionObserver" in window) {
        this.intersectionObserver?.disconnect();
        this.intersectionObserver = null;
      }
    }
  }
}
