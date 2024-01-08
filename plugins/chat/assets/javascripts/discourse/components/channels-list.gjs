import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";
import ChannelsListPublic from "discourse/plugins/chat/discourse/components/channels-list-public";

export default class ChannelsList extends Component {
  @service chat;

  <template>
    <ChannelsListPublic />

    {{#if this.chat.userCanDirectMessage}}
      <ChannelsListDirect />
    {{/if}}
  </template>
}
