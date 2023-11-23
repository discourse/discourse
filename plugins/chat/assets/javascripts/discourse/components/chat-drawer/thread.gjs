import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import and from "truth-helpers/helpers/and";
import ChatDrawerHeader from "discourse/plugins/chat/discourse/components/chat-drawer/header";
import ChatDrawerHeaderBackLink from "discourse/plugins/chat/discourse/components/chat-drawer/header/back-link";
import ChatDrawerHeaderRightActions from "discourse/plugins/chat/discourse/components/chat-drawer/header/right-actions";
import ChatDrawerHeaderTitle from "discourse/plugins/chat/discourse/components/chat-drawer/header/title";
import ChatThread from "discourse/plugins/chat/discourse/components/chat-thread";

export default class ChatDrawerThread extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;
  @service chatHistory;

  get backLink() {
    const link = {
      models: this.chat.activeChannel.routeModels,
    };

    if (this.chatHistory.previousRoute?.name === "chat.channel.threads") {
      link.title = I18n.t("chat.return_to_threads_list");
      link.route = "chat.channel.threads";
    } else {
      link.title = I18n.t("chat.return_to_channel");
      link.route = "chat.channel";
    }

    return link;
  }

  get threadTitle() {
    return (
      this.chat.activeChannel?.activeThread?.title ??
      I18n.t("chat.thread.label")
    );
  }

  @action
  fetchChannelAndThread() {
    if (!this.args.params?.channelId || !this.args.params?.threadId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.activeChannel = channel;

        channel.threadsManager
          .find(channel.id, this.args.params.threadId)
          .then((thread) => {
            this.chat.activeChannel.activeThread = thread;
          });
      });
  }

  <template>
    <ChatDrawerHeader @toggleExpand={{@drawerActions.toggleExpand}}>
      {{#if
        (and this.chatStateManager.isDrawerExpanded this.chat.activeChannel)
      }}
        <div class="chat-drawer-header__left-actions">
          <div class="chat-drawer-header__top-line">
            <ChatDrawerHeaderBackLink
              @route={{this.backLink.route}}
              @title={{this.backLink.title}}
              @routeModels={{this.backLink.models}}
            />
          </div>
        </div>
      {{/if}}

      <ChatDrawerHeaderTitle @translatedTitle={{this.threadTitle}} />

      <ChatDrawerHeaderRightActions @drawerActions={{@drawerActions}} />
    </ChatDrawerHeader>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div
        class="chat-drawer-content"
        {{didInsert this.fetchChannelAndThread}}
        {{didUpdate this.fetchChannelAndThread @params.channelId}}
        {{didUpdate this.fetchChannelAndThread @params.threadId}}
      >
        {{#each (array this.chat.activeChannel.activeThread) as |thread|}}
          {{#if thread}}
            <ChatThread
              @thread={{thread}}
              @targetMessageId={{@params.messageId}}
            />
          {{/if}}
        {{/each}}
      </div>
    {{/if}}
  </template>
}
