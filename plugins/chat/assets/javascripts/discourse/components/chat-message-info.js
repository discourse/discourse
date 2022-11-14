import { computed } from "@ember/object";
import Component from "@ember/component";
import { prioritizeNameInUx } from "discourse/lib/settings";

export default class ChatMessageInfo extends Component {
  tagName = "";
  message = null;
  details = null;

  didInsertElement() {
    this._super(...arguments);
    this.message.user?.trackStatus?.();
  }

  willDestroyElement() {
    this._super(...arguments);
    this.message.user?.stopTrackingStatus?.();
  }

  @computed("message.user")
  get name() {
    return this.prioritizeName
      ? this.message.user.name
      : this.message.user.username;
  }

  @computed("message.reviewable_id", "message.user_flag_status")
  get isFlagged() {
    return this.message?.reviewable_id || this.message?.user_flag_status === 0;
  }

  @computed("message.user.name")
  get prioritizeName() {
    return (
      this.siteSettings.display_name_on_posts &&
      prioritizeNameInUx(this.message?.user?.name)
    );
  }

  @computed("message.user.status")
  get showStatus() {
    return !!this.message.user?.status;
  }

  @computed("message.user")
  get usernameClasses() {
    const user = this.message?.user;

    const classes = this.prioritizeName ? ["is-full-name"] : ["is-username"];

    if (!user) {
      return classes;
    }

    if (user.staff) {
      classes.push("is-staff");
    }
    if (user.admin) {
      classes.push("is-admin");
    }
    if (user.moderator) {
      classes.push("is-moderator");
    }
    if (user.groupModerator) {
      classes.push("is-category-moderator");
    }

    return classes.join(" ");
  }
}
