import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatThread from "discourse/plugins/chat/discourse/components/chat-thread";

export default class ChatDrawerRoutesChannelThread extends Component {
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;
  @service chatHistory;

  @tracked showThreadFullTitle = false;

  get showfullTitle() {
    return this.chatStateManager.isDrawerExpanded && this.showThreadFullTitle;
  }

  get backButton() {
    const link = {
      models: this.chat.activeChannel?.routeModels,
    };

    if (this.chatHistory.previousRoute?.name === "chat.channel.threads") {
      link.title = i18n("chat.return_to_threads_list");
      link.route = "chat.channel.threads";
    } else if (this.chatHistory.previousRoute?.name === "chat.threads") {
      link.title = i18n("chat.my_threads.title");
      link.route = "chat.threads";
      link.models = [];
    } else {
      link.title = i18n("chat.return_to_channel");
      link.route = "chat.channel";
    }

    return link;
  }

  get threadTitle() {
    return (
      this.chat.activeChannel?.activeThread?.title ?? i18n("chat.thread.label")
    );
  }

  @action
  async fetchChannelAndThread() {
    if (!this.args.params?.channelId || !this.args.params?.threadId) {
      return;
    }

    try {
      const channel = await this.chatChannelsManager.find(
        this.args.params.channelId
      );

      this.chat.activeChannel = channel;

      channel.threadsManager
        .find(channel.id, this.args.params.threadId)
        .then((thread) => {
          this.chat.activeChannel.activeThread = thread;
        });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  setFullTitle(value) {
    this.showThreadFullTitle = value;
  }

  <template>
    <div
      class="c-drawer-routes --channel-thread"
      {{didInsert this.fetchChannelAndThread}}
      {{didUpdate this.fetchChannelAndThread @params.channelId}}
      {{didUpdate this.fetchChannelAndThread @params.threadId}}
    >
      {{#if this.chat.activeChannel}}
        <Navbar
          @onClick={{this.chat.toggleDrawer}}
          @showFullTitle={{this.showfullTitle}}
          as |navbar|
        >
          <navbar.BackButton
            @title={{this.backButton.title}}
            @route={{this.backButton.route}}
            @routeModels={{this.backButton.models}}
          />
          <navbar.Title @title={{this.threadTitle}} @icon="discourse-threads" />
          <navbar.Actions as |a|>
            <a.ToggleDrawerButton />
            <a.FullPageButton />
            <a.CloseDrawerButton />
          </navbar.Actions>
        </Navbar>

        {{#if this.chatStateManager.isDrawerExpanded}}
          <div class="chat-drawer-content">
            {{#each (array this.chat.activeChannel.activeThread) as |thread|}}
              {{#if thread}}
                <ChatThread
                  @thread={{thread}}
                  @targetMessageId={{@params.messageId}}
                  @setFullTitle={{this.setFullTitle}}
                />
              {{/if}}
            {{/each}}
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
