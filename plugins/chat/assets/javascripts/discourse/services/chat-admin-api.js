import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class ChatAdminApi extends Service {
  async exportMessages() {
    await this.#post(`/export/messages`);
  }

  get #basePath() {
    return "/chat/admin";
  }

  #post(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "POST",
      data,
    });
  }
}
