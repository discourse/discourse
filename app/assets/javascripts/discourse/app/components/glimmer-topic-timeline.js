import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import optionalService from "discourse/lib/optional-service";
import { inject as service } from "@ember/service";

export default class GlimmerTopicTimeline extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;

  @tracked dockAt = null;
  @tracked dockBottom = null;
  @tracked enteredIndex = this.args.enteredIndex;

  adminTools = optionalService();
  intersectionObserver = null;

  constructor() {
    super(...arguments);

    if (this.args.prevEvent) {
      this.enteredIndex = this.args.prevEvent.postIndex - 1;
    }

    if (!this.site.mobileView) {
      this.intersectionObserver = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          const bounds = entry.boundingClientRect;

          if (entry.target.id === "topic-bottom") {
            this.topicBottom = bounds.y + window.scrollY;
          } else {
            this.topicTop = bounds.y + window.scrollY;
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

  get displaySummary() {
    return (
      this.siteSettings.summary_timeline_button &&
      !this.args.fullScreen &&
      this.args.model.has_summary &&
      !this.args.model.postStream.summary
    );
  }

  get class() {
    const classes = [];
    if (this.args.fullscreen) {
      if (this.addShowClass) {
        classes.push("timeline-fullscreen show");
      } else {
        classes.push("timeline-fullscreen");
      }
    }

    if (this.dockAt) {
      classes.push("timeline-docked");
      if (this.dockBottom) {
        classes.push("timeline-docked-bottom");
      }
    }

    return classes.join(" ");
  }

  get addShowClass() {
    return this.args.fullscreen && !this.args.addShowClass;
  }

  get createdAt() {
    return new Date(this.args.model.created_at);
  }

  willDestroy() {
    if (!this.site.mobileView) {
      this.intersectionObserver?.disconnect();
      this.intersectionObserver = null;
    }
  }
}
