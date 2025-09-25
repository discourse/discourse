import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { service } from "@ember/service";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatChannel from "discourse/plugins/chat/discourse/components/chat-channel";

export default class ChatDrawerRoutesChannel extends Component {
  @service chat;
  @service chatStateManager;
  @service chatHistory;

  @tracked channelFilter = "";

  get backBtnRoute() {
    if (this.chatHistory.previousRoute?.name === "chat.browse") {
      return "chat.browse";
    } else if (this.args.model?.channel?.isDirectMessageChannel) {
      return "chat.direct-messages";
    } else {
      return "chat.channels";
    }
  }

  <template>
    <div class="c-drawer-routes --channel">
      {{#if @model.channel}}
        <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
          <navbar.BackButton @route={{this.backBtnRoute}} />
          <navbar.ChannelTitle @channel={{@model.channel}} />
          <navbar.Actions as |a|>
            <a.SearchInput
              @channel={{@model.channel}}
              @onFilter={{fn (mut this.channelFilter)}}
            />
            <a.ThreadsListButton @channel={{@model.channel}} />
            <a.ToggleDrawerButton />
            <a.FullPageButton />
            <a.CloseDrawerButton />
          </navbar.Actions>
        </Navbar>

        {{#if this.chatStateManager.isDrawerExpanded}}
          <div class="chat-drawer-content">
            {{#each (array @model.channel) as |channel|}}
              <ChatChannel
                @targetMessageId={{readonly @params.messageId}}
                @channel={{channel}}
                @channelFilter={{this.channelFilter}}
              />
            {{/each}}
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
