import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatModalManageStarredChannels from "./chat/modal/manage-starred-channels";
import ChatChannelRow from "./chat-channel-row";

export default class ChannelsListStarred extends Component {
  @service chatChannelsManager;
  @service chatStateManager;
  @service modal;
  @service site;

  get channelList() {
    return this.args.channels || this.chatChannelsManager.starredChannels;
  }

  get hasChannels() {
    return this.channelList.length > 0;
  }

  get showHeader() {
    return this.site.desktopView && this.chatStateManager.isDrawerExpanded;
  }

  @action
  openManageStarredModal() {
    this.modal.show(ChatModalManageStarredChannels);
  }

  <template>
    {{#if this.showHeader}}
      <div class="chat-channel-divider starred-channels-section">
        <span class="channel-title">{{i18n "chat.starred_channels"}}</span>

        <button
          type="button"
          class="btn no-text btn-flat open-manage-starred-btn title-action"
          title={{i18n "chat.manage_starred_channels.title"}}
          {{on "click" this.openManageStarredModal}}
        >
          {{icon "pencil"}}
        </button>
      </div>
    {{/if}}

    <div class="channels-list-container starred-channels">
      {{#if this.hasChannels}}
        {{#each this.channelList as |channel|}}
          <ChatChannelRow
            @channel={{channel}}
            @options={{hash leaveButton=channel.isDirectMessageChannel}}
          />
        {{/each}}
      {{else}}
        <div class="chat-channel-list__empty">
          <span class="chat-channel-list__empty-message">
            {{i18n "chat.starred_channels_empty"}}
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
