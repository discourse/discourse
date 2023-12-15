import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";

export default class ChatRoutesChannelInfo extends Component {
  @service chatChannelInfoRouteOriginManager;
  @service site;
  @service modal;
  @service chatGuardian;

  membersLabel = I18n.t("chat.channel_info.tabs.members");
  settingsLabel = I18n.t("chat.channel_info.tabs.settings");
  backToChannelLabel = I18n.t("chat.channel_info.back_to_all_channel");
  backToAllChannelsLabel = I18n.t("chat.channel_info.back_to_channel");

  get showTabs() {
    return this.site.desktopView && this.args.channel.isOpen;
  }

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

      <div class="chat-channel-info">
        {{#if this.showTabs}}
          <nav class="chat-channel-info__nav">
            <ul class="nav nav-pills">
              <li>
                <LinkTo
                  @route="chat.channel.info.settings"
                  @model={{@channel}}
                  @replace={{true}}
                >
                  {{this.settingsLabel}}
                </LinkTo>
              </li>
              <li>
                <LinkTo
                  @route="chat.channel.info.members"
                  @model={{@channel}}
                  @replace={{true}}
                >
                  {{this.membersLabel}}
                </LinkTo>
              </li>
            </ul>
          </nav>
        {{/if}}

        {{outlet}}
      </div>
    </div>
  </template>
}
