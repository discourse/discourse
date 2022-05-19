import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class UserStatusService extends Service {
  async set(status) {
    await ajax({
      url: "/user-status.json",
      type: "PUT",
      data: { description: status.description },
    });

    this.currentUser.status = status;
  }

  async clear() {
    await ajax({
      url: "/user-status.json",
      type: "DELETE",
    });

    this.currentUser.status = null;
  }
}
