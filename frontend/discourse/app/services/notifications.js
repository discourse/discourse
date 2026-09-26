import { tracked } from "@glimmer/tracking";
import Service, { service } from "discourse/lib/service";
import { disableImplicitInjections } from "discourse/lib/disable-implicit-injections";
import CurrentUserService from "discourse/services/current-user";

@disableImplicitInjections
export default class NotificationsService extends Service {
  @service(() => CurrentUserService) currentUser;

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
