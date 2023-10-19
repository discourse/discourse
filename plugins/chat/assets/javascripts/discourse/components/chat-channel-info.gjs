import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import ChatChannelStatus from "discourse/plugins/chat/discourse/components/chat-channel-status";
import ChatChannelTitle from "discourse/plugins/chat/discourse/components/chat-channel-title";

export default class ChatChannelMessageEmojiPicker extends Component {
  @service chatChannelInfoRouteOriginManager;
  @service site;

  membersLabel = I18n.t("chat.channel_info.tabs.members");
  settingsLabel = I18n.t("chat.channel_info.tabs.settings");
  backToChannelLabel = I18n.t("chat.channel_info.back_to_all_channel");
  backToAllChannelsLabel = I18n.t("chat.channel_info.back_to_channel");

  get showTabs() {
    return (
      this.site.desktopView &&
      this.args.channel.membershipsCount > 1 &&
      this.args.channel.isOpen
    );
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
