import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import I18n from "discourse-i18n";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import ChannelInfoNav from "./channel-info-nav";

export default class ChatRoutesChannelInfo extends Component {
  @service chatChannelInfoRouteOriginManager;
  @service site;
  @service modal;
  @service chatGuardian;

  backToChannelLabel = I18n.t("chat.channel_info.back_to_all_channels");
  backToAllChannelsLabel = I18n.t("chat.channel_info.back_to_channel");

  get canEditChannel() {
    return (
      this.chatGuardian.canEditChatChannel() &&
      (this.args.channel.isCategoryChannel ||
        (this.args.channel.isDirectMessageChannel &&
          this.args.channel.chatable.group))
    );
  }

  @action
  editChannelTitle() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.args.channel,
    });
  }

  <template>
    <div class="c-routes-channel-info">
      <Navbar as |navbar|>
        {{#if this.chatChannelInfoRouteOriginManager.isBrowse}}
          <navbar.BackButton
            @route="chat.browse"
            @title={{this.backToAllChannelsLabel}}
          />
        {{else}}
          <navbar.BackButton
            @route="chat.channel"
            @routeModels={{@channel.routeModels}}
            @title={{this.backToChannelLabel}}
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
