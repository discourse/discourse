import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import KeyValueStore from "discourse/lib/key-value-store";

export default class Rewind extends Service {
  @service currentUser;

  @tracked dismissed = this.store.getObject("_dismissed") ?? false;

  store = new KeyValueStore("discourse_rewind_" + this.fetchRewindYear);

  @tracked
  _isDisabled = this.currentUser?.user_option?.discourse_rewind_disabled;

  get active() {
    return this.currentUser?.is_rewind_active;
  }

  get disabled() {
    return this._isDisabled ?? false;
  }

  set disabled(value) {
    this._isDisabled = value;
  }

  // We want to show the previous year's rewind in January
  // but the current year's rewind in any other month (in
  // reality, only December).
  get fetchRewindYear() {
    const currentDate = new Date();
    const currentMonth = currentDate.getMonth();
    const currentYear = currentDate.getFullYear();

    if (currentMonth === 0) {
      return currentYear - 1;
    } else {
      return currentYear;
    }
  }

  get fetchRewindNextYear() {
    const currentDate = new Date();
    const currentMonth = currentDate.getMonth();
    const currentYear = currentDate.getFullYear();

    if (currentMonth === 0) {
      return currentYear;
    } else {
      return currentYear + 1;
    }
  }

  dismiss() {
    this.dismissed = true;
    this.store.setObject({ key: "_dismissed", value: true });
  }
}
