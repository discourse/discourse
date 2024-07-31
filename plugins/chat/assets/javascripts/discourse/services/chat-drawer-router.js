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
    extractParams: () => ({ currentTab: "open" }),
  },
  "chat.browse.index": {
    name: ChatDrawerRoutesBrowse,
    extractParams: () => ({ currentTab: "open" }),
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
  @service chat;
  @service siteSettings;
  @service chatStateManager;
  @service chatChannelsManager;

  @tracked component = null;
  @tracked drawerRoute = null;
  @tracked params = null;

  routeNames = Object.keys(ROUTES);

  get hasThreads() {
    if (!this.siteSettings.chat_threads_enabled) {
      return false;
    }

    return this.chatChannelsManager.hasThreadedChannels;
  }

  get hasDirectMessages() {
    return this.chat.userCanAccessDirectMessages;
  }

  #routeFromURL(url) {
    let route = this.router.recognize(url);

    // ember might recognize the index subroute
    if (route.localName === "index") {
      route = route.parent;
    }

    return route;
  }

  #redirect() {
    if (
      this.siteSettings.chat_preferred_index === "my_threads" &&
      this.hasThreads
    ) {
      return this.stateFor(this.#routeFromURL("/chat/threads"));
    }
    if (
      this.siteSettings.chat_preferred_index === "direct_messages" &&
      this.hasDirectMessages
    ) {
      return this.stateFor(this.#routeFromURL("/chat/direct-messages"));
    }

    if (!this.siteSettings.enable_public_channels) {
      return this.stateFor(this.#routeFromURL("/chat/direct-messages"));
    }
  }

  stateFor(route) {
    this.drawerRoute?.deactivate?.(this.chatHistory.currentRoute);

    this.chatHistory.visit(route);
    this.drawerRoute = ROUTES[route.name];
    this.params = this.drawerRoute?.extractParams?.(route) || route.params;
    this.component = this.drawerRoute?.name || ChatDrawerRoutesChannels;

    if (
      !this.chatStateManager.isDrawerActive && // only when opening the drawer
      this.component.name === "ChatDrawerRoutesChannels" // we should check if redirect to channels
    ) {
      this.#redirect();
    }

    this.currentRouteName = route.name;
    this.drawerRoute.activate?.(route);
  }
}
