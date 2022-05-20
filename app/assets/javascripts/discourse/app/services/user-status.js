import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class UserStatusService extends Service {
  @service appEvents;

  async set(status) {
    await ajax({
      url: "/user-status.json",
      type: "PUT",
      data: { description: status.description },
    });

    this.currentUser.set("status", status);
    this.appEvents.trigger("do-not-disturb:changed");
  }

  async clear() {
    await ajax({
      url: "/user-status.json",
      type: "DELETE",
    });

    this.currentUser.set("status", null);
    this.appEvents.trigger("do-not-disturb:changed");
  }
}
