import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { popupAjaxError } from "discourse/lib/ajax-error";

// Loaded on demand: the drawer outlet renders on every page, so importing the drawer route
// components here would pull most of chat's UI into the bundle for every request.
const loadDrawerRoutes = () => import("../lib/chat-drawer-routes");

const ROUTES = {
  chat: {
    component: "Channels",
    redirect: (context) => {
      if (
        context.siteSettings.chat_preferred_index === "my_threads" &&
        context.hasThreads
      ) {
        return "/chat/threads";
      }

      if (
        context.siteSettings.chat_preferred_index === "direct_messages" &&
        context.hasDirectMessages
      ) {
        return "/chat/direct-messages";
      }

      if (!context.siteSettings.enable_public_channels) {
        return "/chat/direct-messages";
      }
    },
  },
  "chat.browse": {
    component: "Browse",
    extractParams: () => ({ currentTab: "open" }),
  },
  "chat.browse.open": {
    component: "Browse",
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.archived": {
    component: "Browse",
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.closed": {
    component: "Browse",
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.all": {
    component: "Browse",
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.channels": { component: "Channels" },
  "chat.channel": {
    component: "Channel",

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      return { channel };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.thread": {
    component: "ChannelThread",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        threadId: route.params.threadId,
      };
    },

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      const thread = await channel.threadsManager.find(
        channel.id,
        params.threadId
      );

      return { channel, thread };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
      this.chat.activeChannel.activeThread = model.thread;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.thread.near-message": {
    component: "ChannelThread",

    extractParams: (route) => {
      return {
        channelId: route.parent.parent.params.channelId,
        threadId: route.parent.params.threadId,
        messageId: route.params.messageId,
      };
    },

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);

      const thread = await channel.threadsManager.find(
        channel.id,
        params.threadId
      );

      return { channel, thread };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
      this.chat.activeChannel.activeThread = model.thread;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.threads": {
    component: "ChannelThreads",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      return { channel };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.pins": {
    component: "ChannelPins",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      const pinnedMessages = await this.chatApi.pinnedMessages(channel);
      return { channel, pinnedMessages };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.direct-messages": {
    component: "DirectMessages",
  },
  "chat.starred-channels": {
    component: "StarredChannels",
    redirect: (context) => {
      if (!context.chatChannelsManager.hasStarredChannels) {
        return "/chat/channels";
      }
    },
  },
  "chat.threads": {
    component: "Threads",
  },
  "chat.search": {
    component: "Search",
  },
  "chat.channel.near-message": {
    component: "Channel",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        messageId: route.params.messageId,
      };
    },

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      return { channel };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.near-message-with-thread": {
    component: "Channel",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
        messageId: route.params.messageId,
      };
    },

    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      return { channel };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.info.settings": {
    component: "ChannelInfoSettings",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },
    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      return { channel };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
  "chat.channel.info.members": {
    component: "ChannelInfoMembers",

    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },
    async model(params) {
      const channel = await this.chatChannelsManager.find(params.channelId);
      return { channel };
    },

    afterModel(model) {
      this.chat.activeChannel = model.channel;
    },

    deactivate() {
      this.chat.activeChannel = null;
    },
  },
};

export default class ChatDrawerRouter extends Service {
  @service router;
  @service chatHistory;
  @service chat;
  // eslint-disable-next-line discourse/no-unused-services -- used in ROUTES model functions
  @service chatApi;
  @service siteSettings;
  @service chatChannelsManager;

  @tracked component = null;
  @tracked drawerRoute = null;
  @tracked params = null;
  @tracked currentRouteName = null;
  @tracked model = null;

  routeNames = Object.keys(ROUTES);

  canHandleRoute(route) {
    return !!ROUTES[this.#forceParentRouteForIndex(route).name];
  }

  get activeChannelId() {
    return this.model?.channel?.id;
  }

  get hasThreads() {
    if (!this.siteSettings.chat_threads_enabled) {
      return false;
    }

    return this.chatChannelsManager.shouldShowMyThreads;
  }

  get hasDirectMessages() {
    return this.chat.userCanAccessDirectMessages;
  }

  async stateFor(route) {
    this.drawerRoute?.deactivate?.call(this, this.chatHistory.currentRoute);
    this.chatHistory.visit(route);
    this.drawerRoute = ROUTES[this.#forceParentRouteForIndex(route).name];
    this.params =
      this.drawerRoute?.extractParams?.call(this, route) || route.params;

    try {
      this.model = await this.drawerRoute?.model?.call(this, this.params);
      this.drawerRoute?.afterModel?.call(this, this.model);
    } catch (e) {
      popupAjaxError(e);
    }

    const drawerRoutes = await waitForPromise(loadDrawerRoutes());
    this.component = drawerRoutes[this.drawerRoute?.component || "Channels"];
    this.currentRouteName = route.name;
    this.drawerRoute.activate?.(route);

    const redirectedRoute = this.drawerRoute.redirect?.(this);
    if (redirectedRoute) {
      await this.stateFor(this.#routeFromURL(redirectedRoute));
    }
  }

  #routeFromURL(url) {
    const route = this.router.recognize(url);
    return this.#forceParentRouteForIndex(route);
  }

  #forceParentRouteForIndex(route) {
    // ember might recognize the index subroute
    if (route.localName === "index") {
      return route.parent;
    }

    return route;
  }
}
