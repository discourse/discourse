import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";

export default class ChatChannelMessageEmojiPicker extends Component {
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
    <div class="chat-full-page-header">
      <div class="chat-channel-header-details">
        <div class="chat-full-page-header__left-actions">
          {{#if this.chatChannelInfoRouteOriginManager.isBrowse}}
            <LinkTo
              @route="chat.browse"
              class="chat-full-page-header__back-btn no-text btn-flat btn"
              title={{this.backToAllChannelsLabel}}
            >
              {{icon "chevron-left"}}
            </LinkTo>
          {{else}}
            <LinkTo
              @route="chat.channel"
              @models={{@channel.routeModels}}
              class="chat-full-page-header__back-btn no-text btn-flat btn"
              title={{this.backToChannelLabel}}
            >
              {{icon "chevron-left"}}
            </LinkTo>
          {{/if}}
        </div>

        <ChatChannelTitle @channel={{@channel}} />

        {{#if this.canEditChannel}}
          <DButton
            @icon="pencil-alt"
            class="btn-flat"
            @action={{this.editChannelTitle}}
          />
        {{/if}}
      </div>
    </div>

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
  </template>
}
