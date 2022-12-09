import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ChatChannelRow extends Component {
  @service router;
  @service chat;
  @service currentUser;
  @service site;

  @action
  startTrackingStatus() {
    this.#firstDirectMessageUser?.trackStatus();
  }

  @action
  stopTrackingStatus() {
    this.#firstDirectMessageUser?.stopTrackingStatus();
  }

  get channelHasUnread() {
    return (
      this.currentUser.get(
        `chat_channel_tracking_state.${this.args.channel?.id}.unread_count`
      ) > 0
    );
  }

  get #firstDirectMessageUser() {
    return this.args.channel?.chatable?.users?.firstObject;
  }
}
