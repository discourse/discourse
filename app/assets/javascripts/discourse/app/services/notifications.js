import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class NotificationsService extends Service {
  @service currentUser;

  @tracked isInDoNotDisturb;

  #dndTimer;

  constructor() {
    super(...arguments);

    this._checkDoNotDisturb();
  }

  willDestroy() {
    clearTimeout(this.#dndTimer);
  }

  _checkDoNotDisturb() {
    clearTimeout(this.#dndTimer);

    if (this.currentUser?.do_not_disturb_until) {
      const remainingMs =
        new Date(this.currentUser.do_not_disturb_until) - Date.now();

      if (remainingMs <= 0) {
        this.isInDoNotDisturb = false;
        return;
      }

      this.isInDoNotDisturb = true;

      this.#dndTimer = setTimeout(
        () => this._checkDoNotDisturb(),
        Math.min(remainingMs, 60000)
      );
    } else {
      this.isInDoNotDisturb = false;
    }
  }
}
