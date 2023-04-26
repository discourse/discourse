import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { inject as service } from "@ember/service";
import Component from "@ember/component";
import { action } from "@ember/object";
import { cloneJSON } from "discourse-common/lib/object";
export default class ChatDraftChannelScreen extends Component {
  @service chat;
  @service router;
  tagName = "";

  @action
  onCancelChatDraft() {
    return this.router.transitionTo("chat.index");
  }

  @action
  onChangeSelectedUsers(users) {
    this._fetchPreviewedChannel(users);
  }

  @action
  onSwitchFromDraftChannel(channel) {
    channel.set("isDraft", false);
  }

  _fetchPreviewedChannel(users) {
    this.set("previewedChannel", null);

    return this.chat
      .getDmChannelForUsernames(users.mapBy("username"))
      .then((response) => {
        this.set(
          "previewedChannel",
          ChatChannel.create(
            Object.assign({}, response.channel, { isDraft: true })
          )
        );
      })
      .catch((error) => {
        if (error?.jqXHR?.status === 404) {
          this.set(
            "previewedChannel",
            ChatChannel.create({
              chatable: { users: cloneJSON(users) },
              isDraft: true,
            })
          );
        }
      });
  }
}
