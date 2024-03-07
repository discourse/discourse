import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";

export default class DoNotDisturb extends Component {
  @service currentUser;
  @service router;

  @tracked flash;

  @action
  async saveDuration(duration) {
    try {
      await this.currentUser.enterDoNotDisturbFor(duration);
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  navigateToNotificationSchedule() {
    this.router.transitionTo("preferences.notifications", this.currentUser);
    this.args.closeModal();
  }
}
