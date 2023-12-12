import { tracked } from "@glimmer/tracking";
import Service, { inject as service } from "@ember/service";
import ChatDrawerChannel from "discourse/plugins/chat/discourse/components/chat-drawer/channel";
import ChatDrawerChannelThreads from "discourse/plugins/chat/discourse/components/chat-drawer/channel-threads";
import ChatDrawerIndex from "discourse/plugins/chat/discourse/components/chat-drawer/index";
import ChatDrawerThread from "discourse/plugins/chat/discourse/components/chat-drawer/thread";
import ChatDrawerThreads from "discourse/plugins/chat/discourse/components/chat-drawer/threads";

const ROUTES = {
  "chat.channel": { name: ChatDrawerChannel },
  "chat.channel.thread": {
    name: ChatDrawerThread,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        threadId: route.params.threadId,
      };
    },
  },
  "chat.channel.thread.index": {
    name: ChatDrawerThread,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        threadId: route.params.threadId,
      };
    },
  },
  "chat.channel.thread.near-message": {
    name: ChatDrawerThread,
    extractParams: (route) => {
      return {
        channelId: route.parent.parent.params.channelId,
        threadId: route.parent.params.threadId,
        messageId: route.params.messageId,
      };
    },
  },
  "chat.channel.threads": {
    name: ChatDrawerChannelThreads,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },
  },
  "chat.threads": {
    name: ChatDrawerThreads,
  },
  chat: { name: ChatDrawerIndex },
  "chat.channel.near-message": {
    name: ChatDrawerChannel,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        messageId: route.params.messageId,
      };
    },
  },
  "chat.channel-legacy": {
    name: ChatDrawerChannel,
    extractParams: (route) => {
      return {
        channelId: route.params.channelId,
        messageId: route.queryParams.messageId,
      };
    },
  },
};

export default class ChatDrawerRouter extends Service {
  @service router;
  @service chatHistory;

  @tracked component = null;
  @tracked drawerRoute = null;
  @tracked params = null;

  stateFor(route) {
    this.drawerRoute?.deactivate?.(this.chatHistory.currentRoute);

    this.chatHistory.visit(route);

    this.drawerRoute = ROUTES[route.name];
    this.params = this.drawerRoute?.extractParams?.(route) || route.params;
    this.component = this.drawerRoute?.name || ChatDrawerIndex;

    this.drawerRoute.activate?.(route);
  }
}
