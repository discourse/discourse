import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatThreadList from "discourse/plugins/chat/discourse/components/chat-thread-list";

export default class ChatDrawerRoutesChannelThreads extends Component {
  @service chat;
  @service chatStateManager;

  backLinkTitle = i18n("chat.return_to_list");

  get title() {
    return htmlSafe(
      i18n("chat.threads.list") +
        " - " +
        replaceEmoji(this.args.model.channel.title)
    );
  }

  <template>
    <div class="c-drawer-routes --channel-threads">
      {{#if @model}}
        <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
          <navbar.BackButton
            @title={{this.backLinkTitle}}
            @route="chat.channel"
            @routeModels={{@model.channel.routeModels}}
          />
          <navbar.Title @title={{this.title}} @icon="discourse-threads" />
          <navbar.Actions as |a|>
            <a.ToggleDrawerButton />
            <a.FullPageButton />
            <a.CloseDrawerButton />
          </navbar.Actions>
        </Navbar>

        {{#if this.chatStateManager.isDrawerExpanded}}
          <div class="chat-drawer-content">
            <ChatThreadList
              @channel={{@model.channel}}
              @includeHeader={{false}}
            />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
