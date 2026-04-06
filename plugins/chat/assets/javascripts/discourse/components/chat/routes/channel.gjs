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
  @service chatChannelsManager;
  @service chatHistory;
  @service chatTrackingStateManager;

  @tracked isFiltering = false;

  @action
  toggleIsFiltering() {
    this.isFiltering = !this.isFiltering;
    this.chat.activeMessage = null;
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
    const channel = this.args.channel;
    const currentUrgent = channel.isDirectMessageChannel
      ? channel.tracking.unreadCount +
        channel.tracking.mentionCount +
        channel.tracking.watchedThreadsUnreadCount
      : channel.tracking.mentionCount +
        channel.tracking.watchedThreadsUnreadCount;
    return Math.max(
      0,
      this.chatTrackingStateManager.allChannelUrgentCount - currentUrgent
    );
  }

  get otherChannelsMentionCount() {
    return Math.max(
      0,
      this.chatTrackingStateManager.allChannelMentionCount -
        this.args.channel.tracking.mentionCount
    );
  }

  get otherChannelsUnreadCount() {
    if (this.args.channel.isDirectMessageChannel) {
      return this.chatTrackingStateManager.publicChannelUnreadCount;
    }
    return Math.max(
      0,
      this.chatTrackingStateManager.publicChannelUnreadCount -
        this.args.channel.tracking.unreadCount
    );
  }

  get otherChannelsHasUnreadThreads() {
    return this.chatChannelsManager.allChannels.some(
      (c) => c.id !== this.args.channel.id && c.unreadThreadsCount > 0
    );
  }

  <template>
    <div class="c-routes --channel">
      <Navbar as |navbar|>
        {{#if this.site.mobileView}}
          <navbar.BackButton
            @route={{this.getChannelsRoute}}
            @urgentCount={{this.otherChannelsUrgentCount}}
            @unreadCount={{this.otherChannelsUnreadCount}}
            @mentionCount={{this.otherChannelsMentionCount}}
            @hasUnreadThreads={{this.otherChannelsHasUnreadThreads}}
          />
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
          <a.PinnedMessagesButton @channel={{@channel}} />
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
