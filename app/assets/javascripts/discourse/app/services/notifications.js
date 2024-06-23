import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import ReactiveTargetDate from "discourse/lib/reactive-target-date";

@disableImplicitInjections
export default class NotificationsService extends Service {
  @service currentUser;

  #dndReactiveTargetDate;

  /**
   * Whether the current user is in do not disturb mode.
   * This getter is autotrackable, and will recompute when the 'do not disturb until'
   * value changes, or when the threshold is passed.
   */
  get isInDoNotDisturb() {
    if (!this.currentUser) {
      return false;
    }

    if (!this.currentUser.do_not_disturb_until) {
      return false;
    }

    this.#dndReactiveTargetDate ??= new ReactiveTargetDate(
      () => this.currentUser.do_not_disturb_until
    );

    return !this.#dndReactiveTargetDate.hasPassed;
  }

  willDestroy() {
    this.#dndReactiveTargetDate?.destroy();
  }
}
