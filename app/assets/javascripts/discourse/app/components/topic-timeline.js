import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class TopicTimeline extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked enteredIndex = this.args.enteredIndex;
  @tracked docked = false;
  @tracked dockedBottom = false;

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
