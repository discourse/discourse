import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import optionalService from "discourse/lib/optional-service";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";

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

  get classes() {
    const classes = [];
    if (this.args.fullscreen) {
      classes.push("timeline-fullscreen");
    }

    if (this.dockAt) {
      classes.push("timeline-docked");
      if (this.dockBottom) {
        classes.push("timeline-docked-bottom");
      }
    }

    return classes.join(" ");
  }

  get createdAt() {
    return new Date(this.args.model.created_at);
  }

  @bind
  addShowClass(element) {
    if (this.args.fullscreen && !this.args.addShowClass) {
      element.classList.add("show");
    }
  }

  @bind
  addUserTip(element) {
    this.currentUser.showUserTip({
      id: "topic_timeline",
      titleText: I18n.t("user_tips.topic_timeline.title"),
      contentText: I18n.t("user_tips.topic_timeline.content"),
      reference: document.querySelector("div.timeline-scrollarea-wrapper"),
      appendTo: element,
      placement: "left",
    });
  }

  willDestroy() {
    if (!this.site.mobileView) {
      this.intersectionObserver?.disconnect();
      this.intersectionObserver = null;
    }
  }
}
