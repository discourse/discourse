import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedArray } from "tracked-built-ins";
import ChatNotice from "../models/chat-notice";

export default class ChatChannelNoticesManager extends Service {
  @tracked notices = new TrackedArray();

  handleNotice(data) {
    this.notices.pushObject(ChatNotice.create(data));
  }

  clearNotice(notice) {
    this.notices.removeObject(notice);
  }
}
