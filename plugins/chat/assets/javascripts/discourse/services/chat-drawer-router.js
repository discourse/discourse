import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import ChatDrawerRoutesChannel from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel";
import ChatDrawerRoutesChannelThread from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel-thread";
import ChatDrawerRoutesChannelThreads from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel-threads";
import ChatDrawerRoutesChannels from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channels";
import ChatDrawerRoutesThreads from "discourse/plugins/chat/discourse/components/chat/drawer-routes/threads";

const ROUTES = {
  "chat.channel": { name: ChatDrawerRoutesChannel },
  "chat.channel.thread": {
    name: ChatDrawerRoutesChannelThread,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        threadId: route.params.threadId,
      };
    },
  },
  "chat.channel.thread.index": {
    name: ChatDrawerRoutesChannelThread,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        threadId: route.params.threadId,
      };
    },
  },
  "chat.channel.thread.near-message": {
    name: ChatDrawerRoutesChannelThread,
    extractParams: (route) => {
      return {
        channelId: route.parent.parent.params.channelId,
        threadId: route.parent.params.threadId,
        messageId: route.params.messageId,
      };
    },
  },
  "chat.channel.threads": {
    name: ChatDrawerRoutesChannelThreads,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },
  },
  "chat.threads": {
    name: ChatDrawerRoutesThreads,
  },
  chat: { name: ChatDrawerRoutesChannels },
  "chat.channel.near-message": {
    name: ChatDrawerRoutesChannel,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        messageId: route.params.messageId,
      };
    },
  },
  "chat.channel.near-message-with-thread": {
    name: ChatDrawerRoutesChannel,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        messageId: route.params.messageId,
      };
    },
  },
  "chat.channel-legacy": {
    name: ChatDrawerRoutesChannel,
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
    this.component = this.drawerRoute?.name || ChatDrawerRoutesChannels;

    this.drawerRoute.activate?.(route);
  }
}
