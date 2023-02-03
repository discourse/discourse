import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import optionalService from "discourse/lib/optional-service";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";

export default class GlimmerTopicTimeline extends Component {
  @service siteSettings;

  @tracked enteredIndex = this.args.enteredIndex;

  adminTools = optionalService();

  constructor() {
    super(...arguments);

    if (this.args.prevEvent) {
      this.enteredIndex = this.args.prevEvent.postIndex - 1;
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
}
