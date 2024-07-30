import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import ChatDrawerRoutesBrowse from "discourse/plugins/chat/discourse/components/chat/drawer-routes/browse";
import ChatDrawerRoutesChannel from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel";
import ChatDrawerRoutesChannelInfoMembers from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel-info-members";
import ChatDrawerRoutesChannelInfoSettings from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel-info-settings";
import ChatDrawerRoutesChannelThread from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel-thread";
import ChatDrawerRoutesChannelThreads from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channel-threads";
import ChatDrawerRoutesChannels from "discourse/plugins/chat/discourse/components/chat/drawer-routes/channels";
import ChatDrawerRoutesDirectMessages from "discourse/plugins/chat/discourse/components/chat/drawer-routes/direct-messages";
import ChatDrawerRoutesThreads from "discourse/plugins/chat/discourse/components/chat/drawer-routes/threads";

const ROUTES = {
  chat: { name: ChatDrawerRoutesChannels },
  "chat.index": { name: ChatDrawerRoutesChannels },
  // order matters, non index before index
  "chat.browse": {
    name: ChatDrawerRoutesBrowse,
    extractParams: () => ({ currentTab: "all" }),
  },
  "chat.browse.index": {
    name: ChatDrawerRoutesBrowse,
    extractParams: () => ({ currentTab: "all" }),
  },
  "chat.browse.open": {
    name: ChatDrawerRoutesBrowse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.archived": {
    name: ChatDrawerRoutesBrowse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.closed": {
    name: ChatDrawerRoutesBrowse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.all": {
    name: ChatDrawerRoutesBrowse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.channels": { name: ChatDrawerRoutesChannels },
  "chat.channel": { name: ChatDrawerRoutesChannel },
  "chat.channel.index": { name: ChatDrawerRoutesChannel },
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
  "chat.direct-messages": {
    name: ChatDrawerRoutesDirectMessages,
  },
  "chat.threads": {
    name: ChatDrawerRoutesThreads,
  },
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
  "chat.channel.info.settings": {
    name: ChatDrawerRoutesChannelInfoSettings,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },
  },
  "chat.channel.info.members": {
    name: ChatDrawerRoutesChannelInfoMembers,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
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

  routeNames = Object.keys(ROUTES);

  stateFor(route) {
    this.drawerRoute?.deactivate?.(this.chatHistory.currentRoute);

    this.chatHistory.visit(route);

    this.drawerRoute = ROUTES[route.name];
    this.params = this.drawerRoute?.extractParams?.(route) || route.params;
    this.component = this.drawerRoute?.name || ChatDrawerRoutesChannels;
    this.currentRouteName = route.name;

    this.drawerRoute.activate?.(route);
  }
}
