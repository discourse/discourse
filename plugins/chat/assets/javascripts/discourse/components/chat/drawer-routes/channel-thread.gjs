import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatThread from "discourse/plugins/chat/discourse/components/chat-thread";

export default class ChatDrawerRoutesChannelThread extends Component {
  @service chat;
  @service chatStateManager;
  @service chatHistory;

  get backButton() {
    const link = {
      models: this.args.model?.channel?.routeModels,
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
      this.args.model?.channel?.activeThread?.title ?? i18n("chat.thread.label")
    );
  }

  <template>
    <div class="c-drawer-routes --channel-thread">
      {{#if @model.channel}}
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
            {{#each (array @model.thread) as |thread|}}
              <ChatThread
                @thread={{thread}}
                @targetMessageId={{@params.messageId}}
              />
            {{/each}}
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
