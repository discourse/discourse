import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import ChatNotice from "../models/chat-notice";

export default class ChatChannelNoticesManager extends Service {
  @tracked notices = new TrackedArray();

  handleNotice(data) {
    this.notices.push(ChatNotice.create(data));
  }

  clearNotice(notice) {
    this.notices = new TrackedArray(
      this.notices.filter((n) => n.id !== notice.id)
    );
  }
}
