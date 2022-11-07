import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default createWidget("topic-chat-button", {
  tagName: "button.btn.btn-default.topic-chat-button",
  title: "chat.open",

  click() {
    this.appEvents.trigger(
      "chat:open-channel-for-chatable",
      ChatChannel.create(this.attrs.chat_channel)
    );
  },

  template: hbs`
    {{d-icon "far-comments"}}
    <span class="label">
      {{i18n "chat.topic_button_title"}}
    </span>
  `,
});
