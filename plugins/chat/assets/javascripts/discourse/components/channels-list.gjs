import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";
import ChannelsListPublic from "discourse/plugins/chat/discourse/components/channels-list-public";

export default class ChannelsList extends Component {
  @service chat;

  <template>
    <div
      role="region"
      aria-label={{i18n "chat.aria_roles.channels_list"}}
      class="channels-list"
    >
      <ChannelsListPublic />

      {{#if this.chat.userCanAccessDirectMessages}}
        <ChannelsListDirect />
      {{/if}}
    </div>
  </template>
}
