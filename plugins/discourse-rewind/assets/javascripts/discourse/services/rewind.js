import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class Rewind extends Service {
  @service currentUser;

  @tracked
  _isDismissed = this.currentUser?.user_option?.discourse_rewind_dismissed;

  @tracked _isEnabled = this.currentUser?.user_option?.discourse_rewind_enabled;

  get enabled() {
    return this._isEnabled ?? true;
  }

  set enabled(value) {
    this._isEnabled = value;
  }

  get active() {
    return this.currentUser?.is_rewind_active;
  }

  get dismissed() {
    return this._isDismissed ?? false;
  }

  /**
   * We want to show the previous year's rewind in January
   * but the current year's rewind in any other month (in
   * reality, only December).
   */
  get fetchRewindYear() {
    const now = new Date();
    return now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
  }

  dismiss() {
    this._isDismissed = true;
    ajax("/rewinds/dismiss", { type: "POST" });
  }
}
