import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class ChatAdminApi extends Service {
  get #basePath() {
    return "/chat/admin";
  }

  async exportMessages() {
    await this.#post(`/export/messages`);
  }

  #post(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "POST",
      data,
    });
  }
}
