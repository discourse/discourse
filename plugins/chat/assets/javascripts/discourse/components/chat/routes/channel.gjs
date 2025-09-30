import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatSidePanel from "discourse/plugins/chat/discourse/components/chat-side-panel";
import FullPageChat from "discourse/plugins/chat/discourse/components/full-page-chat";

export default class ChatRoutesChannel extends Component {
  @service site;

  @tracked channelFilter = "";

  get getChannelsRoute() {
    return this.args.channel.isDirectMessageChannel
      ? "chat.direct-messages"
      : "chat.channels";
  }

  <template>
    <div class="c-routes --channel">
      <Navbar as |navbar|>
        {{#if this.site.mobileView}}
          <navbar.BackButton @route={{this.getChannelsRoute}} />
        {{/if}}
        <navbar.ChannelTitle @channel={{@channel}} />
        <navbar.Actions as |action|>
          <action.SearchInput
            @channel={{@channel}}
            @onFilter={{fn (mut this.channelFilter)}}
          />
          <action.OpenDrawerButton />
          <action.ThreadsListButton @channel={{@channel}} />
        </navbar.Actions>
      </Navbar>

      <FullPageChat
        @channelFilter={{this.channelFilter}}
        @channel={{@channel}}
        @targetMessageId={{@targetMessageId}}
      />
    </div>

    <ChatSidePanel>
      {{outlet}}
    </ChatSidePanel>
  </template>
}
