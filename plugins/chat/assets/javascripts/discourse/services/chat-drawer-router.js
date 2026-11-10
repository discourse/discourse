import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

// The drawer renders on every page, so its route components load on demand, in one chunk.
const drawerRoutes = () => import("../lib/chat-drawer-routes.js");
const loadChannels = async () => (await drawerRoutes()).Channels;

const ROUTES = {
  chat: {
    component: loadChannels,
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
    component: async () => (await drawerRoutes()).Browse,
    extractParams: () => ({ currentTab: "open" }),
  },
  "chat.browse.open": {
    component: async () => (await drawerRoutes()).Browse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.archived": {
    component: async () => (await drawerRoutes()).Browse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.closed": {
    component: async () => (await drawerRoutes()).Browse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.browse.all": {
    component: async () => (await drawerRoutes()).Browse,
    extractParams: (r) => ({ currentTab: r.localName }),
  },
  "chat.channels": { component: loadChannels },
  "chat.channel": {
    component: async () => (await drawerRoutes()).Channel,
    showsMessages: true,

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
    component: async () => (await drawerRoutes()).ChannelThread,
    showsMessages: true,

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
    component: async () => (await drawerRoutes()).ChannelThread,
    showsMessages: true,

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
    component: async () => (await drawerRoutes()).ChannelThreads,

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
    component: async () => (await drawerRoutes()).ChannelPins,

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
    component: async () => (await drawerRoutes()).DirectMessages,
  },
  "chat.starred-channels": {
    component: async () => (await drawerRoutes()).StarredChannels,
    redirect: (context) => {
      if (!context.chatChannelsManager.hasStarredChannels) {
        return "/chat/channels";
      }
    },
  },
  "chat.threads": {
    component: async () => (await drawerRoutes()).Threads,
  },
  "chat.search": {
    component: async () => (await drawerRoutes()).Search,
  },
  "chat.channel.near-message": {
    component: async () => (await drawerRoutes()).Channel,
    showsMessages: true,

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
    component: async () => (await drawerRoutes()).Channel,
    showsMessages: true,

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
    component: async () => (await drawerRoutes()).ChannelSettings,

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
    component: async () => (await drawerRoutes()).ChannelMembers,

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
  "chat.channel.info.preferences": {
    component: async () => (await drawerRoutes()).ChannelPreferences,

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

  canHandleRoute(route) {
    return !!ROUTES[this.#forceParentRouteForIndex(route).name];
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

    this.component = this.drawerRoute?.component || loadChannels;
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
