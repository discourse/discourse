import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class ChatChannelRow extends Component {
  @service router;
  @service chat;
  @service currentUser;
  @service site;
  @service chatTrackingState;

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
      this.chatTrackingState.getChannelState(this.args.channel.id).unreadCount >
      0
    );
  }

  get #firstDirectMessageUser() {
    return this.args.channel?.chatable?.users?.firstObject;
  }
}
