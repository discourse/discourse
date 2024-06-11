import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";

export default class ChatDrawerRoutesChannel extends Component {
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  get backBtnRoute() {
    if (this.chat.activeChannel?.isDirectMessageChannel) {
      return "chat.direct-messages";
    } else {
      return "chat.channels";
    }
  }

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
    <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
      <navbar.BackButton @route={{this.backBtnRoute}} />
      <navbar.ChannelTitle @channel={{this.chat.activeChannel}} />
      <navbar.Actions as |a|>
        <a.ThreadsListButton @channel={{this.chat.activeChannel}} />
        <a.ToggleDrawerButton />
        <a.FullPageButton />
        <a.CloseDrawerButton />
      </navbar.Actions>
    </Navbar>

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
