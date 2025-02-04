import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
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
  chat: {
    name: ChatDrawerRoutesChannels,
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
  "chat.channel": {
    name: ChatDrawerRoutesChannel,

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
    name: ChatDrawerRoutesChannelThread,

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
    name: ChatDrawerRoutesChannelThread,

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
    name: ChatDrawerRoutesChannelThreads,

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
    name: ChatDrawerRoutesChannel,

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
    name: ChatDrawerRoutesChannelInfoSettings,

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
    name: ChatDrawerRoutesChannelInfoMembers,

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
  @service siteSettings;
  @service chatStateManager;
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

    return this.chatChannelsManager.hasThreadedChannels;
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

    this.component = this.drawerRoute?.name || ChatDrawerRoutesChannels;
    this.currentRouteName = route.name;
    this.drawerRoute.activate?.(route);

    const redirectedRoute = this.drawerRoute.redirect?.(this);
    if (redirectedRoute) {
      this.stateFor(this.#routeFromURL(redirectedRoute));
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
