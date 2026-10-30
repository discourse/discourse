import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import ChannelInfoNav from "./channel-info-nav.gjs";

export default class ChatRoutesChannelInfo extends Component {
  @service chatChannelInfoRouteOriginManager;

  <template>
    <div class="c-routes --channel-info">
      <Navbar as |navbar|>
        {{#if this.chatChannelInfoRouteOriginManager.isBrowse}}
          <navbar.BackButton
            @route="chat.browse"
            @title={{i18n "chat.channel_info.back_to_all_channels"}}
          />
        {{else}}
          <navbar.BackButton
            @route="chat.channel"
            @routeModels={{@channel.routeModels}}
            @title={{i18n "chat.channel_info.back_to_channel"}}
          />
        {{/if}}
        <navbar.ChannelTitle @channel={{@channel}} />
      </Navbar>

      <ChatChannelStatus @channel={{@channel}} />

      <div class="c-channel-info">
        <ChannelInfoNav @channel={{@channel}} />
        {{outlet}}
      </div>
    </div>
  </template>
}
