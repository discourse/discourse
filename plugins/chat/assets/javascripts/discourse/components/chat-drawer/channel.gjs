import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
import ChatChannel from "../chat-channel";
import Header from "./header";
import ChannelTitle from "./header/channel-title";
import LeftActions from "./header/left-actions";
import RightActions from "./header/right-actions";

export default class ChatDrawerChannel extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  @action
  fetchChannel() {
    if (!this.args.params?.channelId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.activeChannel = channel;
      });
  }

  <template>
    <Header @toggleExpand={{@drawerActions.toggleExpand}}>
      <LeftActions />

      <ChannelTitle
        @channel={{this.chat.activeChannel}}
        @drawerActions={{@drawerActions}}
      />

      <RightActions @drawerActions={{@drawerActions}} />
    </Header>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div
        class="chat-drawer-content"
        {{didInsert this.fetchChannel}}
        {{didUpdate this.fetchChannel @params.channelId}}
      >
        {{#if this.chat.activeChannel}}
          {{#each (array this.chat.activeChannel) as |channel|}}
            {{#if channel}}
              <ChatChannel
                @targetMessageId={{readonly @params.messageId}}
                @channel={{channel}}
              />
            {{/if}}
          {{/each}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
