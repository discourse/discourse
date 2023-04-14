import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import optionalService from "discourse/lib/optional-service";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";
import { action } from "@ember/object";

export default class TopicTimeline extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked enteredIndex = this.args.enteredIndex;
  @tracked docked = false;
  @tracked dockedBottom = false;

  adminTools = optionalService();

  constructor() {
    super(...arguments);

    if (this.args.prevEvent) {
      this.enteredIndex = this.args.prevEvent.postIndex - 1;
    }
  }

  get createdAt() {
    return new Date(this.args.model.created_at);
  }

  get classes() {
    const classes = [];
    if (this.args.fullscreen) {
      classes.push("timeline-fullscreen");
    }

    if (this.docked) {
      classes.push("timeline-docked");
      if (this.dockedBottom) {
        classes.push("timeline-docked-bottom");
      }
    }

    return classes.join(" ");
  }

  @bind
  addShowClass(element) {
    if (this.args.fullscreen && !this.args.addShowClass) {
      element.classList.add("show");
    }
  }

  @bind
  addUserTip(element) {
    if (!this.currentUser) {
      return;
    }

    this.currentUser.showUserTip({
      id: "topic_timeline",
      titleText: I18n.t("user_tips.topic_timeline.title"),
      contentText: I18n.t("user_tips.topic_timeline.content"),
      reference: document.querySelector("div.timeline-scrollarea-wrapper"),
      appendTo: element,
      placement: "left",
    });
  }

  @action
  setDocked(value) {
    if (this.docked !== value) {
      this.docked = value;
    }
  }

  @action
  setDockedBottom(value) {
    if (this.dockedBottom !== value) {
      this.dockedBottom = value;
    }
  }
}
