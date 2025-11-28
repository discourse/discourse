import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChatChannelRow from "./chat-channel-row";

export default class ChannelsListStarred extends Component {
  @service chatChannelsManager;

  get channelList() {
    return this.args.channels || this.chatChannelsManager.starredChannels;
  }

  get hasChannels() {
    return this.channelList.length > 0;
  }

  <template>
    <div class="chat-channel-list">
      {{#if this.hasChannels}}
        <div class="chat-channel-list__items">
          {{#each this.channelList as |channel|}}
            <ChatChannelRow
              @channel={{channel}}
              @options={{hash leaveButton=channel.isDirectMessageChannel}}
            />
          {{/each}}
        </div>
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
