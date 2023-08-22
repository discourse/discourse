import Component from "@glimmer/component";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class ChatMessageInfo extends Component {
  @service siteSettings;

  @bind
  trackStatus() {
    this.#user?.trackStatus?.();
  }

  @bind
  stopTrackingStatus() {
    this.#user?.stopTrackingStatus?.();
  }

  get usernameClasses() {
    const user = this.#user;

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
    if (user.new_user) {
      classes.push("is-new-user");
    }
    if (user.primary_group_name) {
      classes.push("group--" + user.primary_group_name);
    }
    return classes.join(" ");
  }

  get name() {
    return this.prioritizeName
      ? this.#user?.get("name")
      : this.#user?.get("username");
  }

  get isFlagged() {
    return this.#message?.reviewableId || this.#message?.userFlagStatus === 0;
  }

  get prioritizeName() {
    return (
      this.siteSettings.display_name_on_posts &&
      prioritizeNameInUx(this.#user?.get("name"))
    );
  }

  get showStatus() {
    return !!this.#user?.get("status");
  }

  get #user() {
    return this.#message?.user;
  }

  get #message() {
    return this.args.message;
  }
}
