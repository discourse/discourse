import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import ChannelsListPublic from "discourse/plugins/chat/discourse/components/channels-list-public";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";

export default class ChannelsList extends Component {
  @service chat;

  <template>
    <ChannelsListPublic />

    {{#if this.chat.userCanDirectMessage}}
      <ChannelsListDirect />
    {{/if}}
  </template>
}