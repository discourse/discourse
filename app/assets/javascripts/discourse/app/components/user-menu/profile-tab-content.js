import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default class UserMenuProfileTabContent extends Component {
  @service currentUser;
  @service siteSettings;
  saving = false;

  get showToggleAnonymousButton() {
    return (
      (this.siteSettings.allow_anonymous_posting &&
        this.currentUser.trust_level >=
          this.siteSettings.anonymous_posting_min_trust_level) ||
      this.currentUser.is_anonymous
    );
  }

  get isInDoNotDisturb() {
    return !!this.#doNotDisturbUntilDate;
  }

  get doNotDisturbDateTime() {
    return this.#doNotDisturbUntilDate.getTime();
  }

  get #doNotDisturbUntilDate() {
    if (!this.currentUser.get("do_not_disturb_until")) {
      return;
    }
    const date = new Date(this.currentUser.get("do_not_disturb_until"));
    if (date < new Date()) {
      return;
    }
    return date;
  }

  @action
  doNotDisturbClick() {
    if (this.saving) {
      return;
    }
    this.saving = true;
    if (this.currentUser.do_not_disturb_until) {
      return this.currentUser.leaveDoNotDisturb().finally(() => {
        this.saving = false;
      });
    } else {
      this.saving = false;
      this.args.closeUserMenu();
      showModal("do-not-disturb");
    }
  }

  @action
  setUserStatusClick() {
    this.args.closeUserMenu();
    showModal("user-status", {
      title: "user_status.set_custom_status",
      modalClass: "user-status",
    });
  }
}
