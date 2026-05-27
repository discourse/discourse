import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import Service from "@ember/service";
import ChatNotice from "../models/chat-notice";

export default class ChatChannelNoticesManager extends Service {
  @tracked notices = trackedArray();

  handleNotice(data) {
    this.notices.push(ChatNotice.create(data));
  }

  clearNotice(notice) {
    this.notices = trackedArray(this.notices.filter((n) => n.id !== notice.id));
  }
}
