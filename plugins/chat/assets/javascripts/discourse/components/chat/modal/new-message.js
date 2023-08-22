import Component from "@glimmer/component";

import { inject as service } from "@ember/service";

export default class ChatModalNewMessage extends Component {
  @service chat;
  @service siteSettings;

  get shouldRender() {
    return (
      this.siteSettings.enable_public_channels || this.chat.userCanDirectMessage
    );
  }
}
