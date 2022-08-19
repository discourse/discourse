import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { longDate, relativeAge } from "discourse/lib/formatter";

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

  get doNotDisturbDateTitle() {
    return longDate(this.#doNotDisturbUntilDate);
  }

  get doNotDisturbDateContent() {
    return relativeAge(this.#doNotDisturbUntilDate);
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
      showModal("do-not-disturb");
    }
  }
}
