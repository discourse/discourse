import Service, { service } from "discourse/lib/service";
import { ajax } from "discourse/lib/ajax";
import DoNotDisturb from "discourse/lib/do-not-disturb";
import { disableImplicitInjections } from "discourse/lib/disable-implicit-injections";
import CurrentUserService from "discourse/services/current-user";
import SiteSettingsService from "discourse/services/site-settings";

@disableImplicitInjections
export default class UserStatusService extends Service {
  @service(() => CurrentUserService) currentUser;
  @service(() => SiteSettingsService) siteSettings;

  get isEnabled() {
    return this.siteSettings.enable_user_status;
  }

  async set(status, pauseNotifications) {
    await ajax({
      url: "/user-status.json",
      type: "PUT",
      data: status,
    });

    this.currentUser.set("status", status);
    if (pauseNotifications) {
      this.#enterDoNotDisturb(status.ends_at);
    } else {
      this.#leaveDoNotDisturb();
    }
  }

  async clear() {
    await ajax({
      url: "/user-status.json",
      type: "DELETE",
    });

    this.currentUser.set("status", null);
    this.#leaveDoNotDisturb();
  }

  #enterDoNotDisturb(endsAt) {
    const duration = this.#duration(endsAt ?? DoNotDisturb.forever);
    this.currentUser.enterDoNotDisturbFor(duration);
  }

  #leaveDoNotDisturb() {
    if (!this.currentUser.isInDoNotDisturb()) {
      return;
    }

    this.currentUser.leaveDoNotDisturb();
  }

  #duration(endsAt) {
    return moment.utc(endsAt).diff(moment.utc(), "minutes");
  }
}
