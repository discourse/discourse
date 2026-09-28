import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import NavbarActions from "discourse/plugins/chat/discourse/components/chat/navbar/actions";
import NavbarChannelTitle from "discourse/plugins/chat/discourse/components/chat/navbar/channel-title";
import ChatSidePanel from "discourse/plugins/chat/discourse/components/chat-side-panel";
import FullPageChat from "discourse/plugins/chat/discourse/components/full-page-chat";

const ChannelActions = <template>
  <NavbarActions as |a|>
    {{#if @canSearchChat}}
      <a.Filter
        @channel={{@channel}}
        @isFiltering={{@isFiltering}}
        @onToggleFilter={{@onToggleFilter}}
      />
    {{/if}}

    <a.OpenDrawerButton />
    <a.PinnedMessagesButton @channel={{@channel}} />
    <a.ThreadsListButton @channel={{@channel}} />
  </NavbarActions>
</template>;

export default class ChatRoutesChannel extends Component {
  @service site;
  @service siteSettings;
  @service chat;
  @service chatHistory;
  @service chatStateManager;
  @service chatTrackingStateManager;
  @service currentUser;
  @service mobileTabBar;

  @tracked isFiltering = false;

  get headerNavbarSlot() {
    return this.mobileTabBar.enabled
      ? this.chatStateManager.headerNavbarSlot
      : null;
  }

  get canSearchChat() {
    return this.currentUser && this.siteSettings.chat_search_enabled;
  }

  get getChannelsRoute() {
    if (this.chatHistory.previousRoute?.name === "chat.browse") {
      return "chat.browse";
    } else if (
      this.chatHistory.previousRoute?.name === "chat.starred-channels"
    ) {
      return "chat.starred-channels";
    } else if (this.args.channel.isDirectMessageChannel) {
      return "chat.direct-messages";
    } else {
      return "chat.channels";
    }
  }

  get otherChannelsUrgentCount() {
    return this.chatTrackingStateManager.allChannelUrgentCount({
      exclude: this.args.channel,
    });
  }

  get otherChannelsMentionCount() {
    return this.chatTrackingStateManager.allChannelMentionCount({
      exclude: this.args.channel,
    });
  }

  get otherChannelsUnreadCount() {
    return this.chatTrackingStateManager.publicChannelUnreadCount({
      exclude: this.args.channel,
    });
  }

  get otherChannelsHasUnreadThreads() {
    return this.chatTrackingStateManager.hasUnreadThreads({
      exclude: this.args.channel,
    });
  }

  @action
  toggleIsFiltering() {
    this.isFiltering = !this.isFiltering;
    this.chat.activeMessage = null;
  }

  <template>
    <div
      class={{dConcatClass
        "c-routes --channel"
        (if this.headerNavbarSlot "--navbar-in-header")
      }}
    >
      {{#if this.headerNavbarSlot}}
        {{#in-element this.headerNavbarSlot insertBefore=null}}
          <nav class="c-navbar">
            <NavbarChannelTitle @channel={{@channel}} />
            <ChannelActions
              @canSearchChat={{this.canSearchChat}}
              @channel={{@channel}}
              @isFiltering={{this.isFiltering}}
              @onToggleFilter={{this.toggleIsFiltering}}
            />
          </nav>
        {{/in-element}}
      {{else}}
        <Navbar as |navbar|>
          {{#if this.site.mobileView}}
            <navbar.BackButton
              @hasUnreadThreads={{this.otherChannelsHasUnreadThreads}}
              @mentionCount={{this.otherChannelsMentionCount}}
              @route={{this.getChannelsRoute}}
              @unreadCount={{this.otherChannelsUnreadCount}}
              @urgentCount={{this.otherChannelsUrgentCount}}
            />
          {{/if}}
          <navbar.ChannelTitle @channel={{@channel}} />
          <ChannelActions
            @canSearchChat={{this.canSearchChat}}
            @channel={{@channel}}
            @isFiltering={{this.isFiltering}}
            @onToggleFilter={{this.toggleIsFiltering}}
          />
        </Navbar>
      {{/if}}

      <FullPageChat
        @channel={{@channel}}
        @isFiltering={{this.isFiltering}}
        @onToggleFilter={{this.toggleIsFiltering}}
        @targetMessageId={{@targetMessageId}}
      />
    </div>

    <ChatSidePanel>
      {{outlet}}
    </ChatSidePanel>
  </template>
}
