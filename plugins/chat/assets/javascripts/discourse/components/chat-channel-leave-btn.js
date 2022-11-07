import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { equal } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import { CHATABLE_TYPES } from "discourse/plugins/chat/discourse/models/chat-channel";

export default Component.extend({
  tagName: "",
  channel: null,
  chat: service(),

  isDirectMessageRow: equal(
    "channel.chatable_type",
    CHATABLE_TYPES.directMessageChannel
  ),

  @discourseComputed("isDirectMessageRow")
  leaveChatTitleKey(isDirectMessageRow) {
    if (isDirectMessageRow) {
      return "chat.direct_messages.leave";
    } else {
      return "chat.leave";
    }
  },
});
