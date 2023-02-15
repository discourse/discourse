import Component from "@glimmer/component";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class ChatMessageInfo extends Component {
  @service siteSettings;

  @bind
  trackStatus() {
    this.args.message?.user?.trackStatus?.();
  }

  @bind
  stopTrackingStatus() {
    this.args.message?.user?.stopTrackingStatus?.();
  }

  get usernameClasses() {
    const user = this.args.message?.get("user");
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
    if (user.new_user) {
      classes.push("is-new-user");
    }
    if (user?.primary_group_name?.length) {
      classes.push("group--" + user.primary_group_name);
    }
    return classes.join(" ");
  }

  get name() {
    return this.prioritizeName
      ? this.args.message?.get("user.name")
      : this.args.message?.get("user.username");
  }

  get isFlagged() {
    return (
      this.args.message?.get("reviewable_id") ||
      this.args.message?.get("user_flag_status") === 0
    );
  }

  get prioritizeName() {
    return (
      this.siteSettings.display_name_on_posts &&
      prioritizeNameInUx(this.args.message?.get("user.name"))
    );
  }

  get showStatus() {
    return !!this.args.message?.user?.get("status");
  }
}
