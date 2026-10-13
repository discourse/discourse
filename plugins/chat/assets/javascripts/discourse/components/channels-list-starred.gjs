import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ChatChannelListFilterToggle from "./chat-channel-list-filter-toggle";
import ChatChannelListOptionsButton from "./chat-channel-list-options-button";
import ChatChannelRow from "./chat-channel-row";
import ChatSidebarChannelListFilterEmptyState from "./chat-sidebar-channel-list-filter-empty-state";

export default class ChannelsListStarred extends Component {
  @service chatChannelsManager;
  @service site;

  get inSidebar() {
    return this.args.inSidebar ?? false;
  }

  get channelList() {
    if (this.args.channels) {
      return this.args.channels;
    }
    if (!this.inSidebar) {
      return this.chatChannelsManager.starredChannelsByPreference;
    }
    return this.chatChannelsManager.starredChannels;
  }

  <template>
    {{#unless (or this.inSidebar this.site.mobileView)}}
      <div class="chat-channel-divider starred-channels-section">
        <span class="channel-title">{{i18n "chat.starred_channels"}}</span>

        <div class="chat-channel-divider__actions">
          <ChatChannelListFilterToggle @section="starred" />
          <ChatChannelListOptionsButton @section="starred" />
        </div>
      </div>
    {{/unless}}

    <div class="channels-list-container starred-channels">
      {{#each this.channelList as |channel|}}
        <ChatChannelRow
          @channel={{channel}}
          @options={{hash leaveButton=channel.isDirectMessageChannel}}
        />
      {{else}}
        {{#if this.chatChannelsManager.starredChannels.length}}
          {{#unless this.inSidebar}}
            <ChatSidebarChannelListFilterEmptyState @section="starred" />
          {{/unless}}
        {{else}}
          <div class="chat-channel-list__empty">
            <span class="chat-channel-list__empty-message">
              {{i18n "chat.starred_channels_empty"}}
            </span>
          </div>
        {{/if}}
      {{/each}}
    </div>
  </template>
}
