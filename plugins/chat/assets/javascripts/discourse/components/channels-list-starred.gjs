import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChatChannelRow from "./chat-channel-row";

export default class ChannelsListStarred extends Component {
  @service chatChannelsManager;

  get inSidebar() {
    return this.args.inSidebar ?? false;
  }

  get channelList() {
    if (this.args.channels) {
      return this.args.channels;
    }
    if (!this.inSidebar) {
      return this.chatChannelsManager.starredChannelsByActivity;
    }
    return this.chatChannelsManager.starredChannels;
  }

  <template>
    <div class="channels-list-container starred-channels">
      {{#each this.channelList as |channel|}}
        <ChatChannelRow
          @channel={{channel}}
          @options={{hash leaveButton=channel.isDirectMessageChannel}}
        />
      {{else}}
        <div class="chat-channel-list__empty">
          <span class="chat-channel-list__empty-message">
            {{i18n "chat.starred_channels_empty"}}
          </span>
        </div>
      {{/each}}
    </div>
  </template>
}
