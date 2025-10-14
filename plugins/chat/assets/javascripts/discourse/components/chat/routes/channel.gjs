import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatSidePanel from "discourse/plugins/chat/discourse/components/chat-side-panel";
import FullPageChat from "discourse/plugins/chat/discourse/components/full-page-chat";

export default class ChatRoutesChannel extends Component {
  @service site;
  @service siteSettings;
  @service chat;

  @tracked isFiltering = false;

  @action
  toggleIsFiltering() {
    this.isFiltering = !this.isFiltering;
    this.chat.activeMessage = null;
  }

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
        <navbar.Actions as |a|>
          {{#if this.siteSettings.chat_search_enabled}}
            <a.Filter
              @channel={{@channel}}
              @isFiltering={{this.isFiltering}}
              @onToggleFilter={{this.toggleIsFiltering}}
            />
          {{/if}}

          <a.OpenDrawerButton />
          <a.ThreadsListButton @channel={{@channel}} />
        </navbar.Actions>
      </Navbar>

      <FullPageChat
        @isFiltering={{this.isFiltering}}
        @channel={{@channel}}
        @targetMessageId={{@targetMessageId}}
        @onToggleFilter={{this.toggleIsFiltering}}
      />
    </div>

    <ChatSidePanel>
      {{outlet}}
    </ChatSidePanel>
  </template>
}
