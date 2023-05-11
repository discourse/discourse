import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import ChatDrawerDraftChannel from "discourse/plugins/chat/discourse/components/chat-drawer/draft-channel";
import ChatDrawerChannel from "discourse/plugins/chat/discourse/components/chat-drawer/channel";
import ChatDrawerThread from "discourse/plugins/chat/discourse/components/chat-drawer/thread";
import ChatDrawerThreads from "discourse/plugins/chat/discourse/components/chat-drawer/threads";
import ChatDrawerIndex from "discourse/plugins/chat/discourse/components/chat-drawer/index";

const COMPONENTS_MAP = {
  "chat.draft-channel": { name: ChatDrawerDraftChannel },
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
  "chat.channel.threads": {
    name: ChatDrawerThreads,
    extractParams: (route) => {
      return {
        channelId: route.parent.params.channelId,
      };
    },
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
  @tracked component = null;
  @tracked params = null;
  @tracked history = [];

  get previousRouteName() {
    if (this.history.length > 1) {
      return this.history[this.history.length - 2];
    }
  }

  stateFor(route) {
    this.history.push(route.name);
    if (this.history.length > 10) {
      this.history.shift();
    }

    const component = COMPONENTS_MAP[route.name];
    this.params = component?.extractParams?.(route) || route.params;
    this.component = component?.name || ChatDrawerIndex;
  }
}
