import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatPinnedMessagesList from "discourse/plugins/chat/discourse/components/chat-pinned-messages-list";

export default class ChatDrawerRoutesChannelPins extends Component {
  @service chat;
  @service chatStateManager;

  backLinkTitle = i18n("chat.return_to_list");

  get title() {
    return htmlSafe(
      i18n("chat.pinned_messages.title") +
        " - " +
        replaceEmoji(this.args.model.channel.title)
    );
  }

  <template>
    <div class="c-drawer-routes --channel-pins">
      {{#if @model}}
        <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
          <navbar.BackButton
            @title={{this.backLinkTitle}}
            @route="chat.channel"
            @routeModels={{@model.channel.routeModels}}
          />
          <navbar.Title @title={{this.title}} @icon="thumbtack" />
          <navbar.Actions as |a|>
            <a.ToggleDrawerButton />
            <a.FullPageButton />
            <a.CloseDrawerButton />
          </navbar.Actions>
        </Navbar>

        {{#if this.chatStateManager.isDrawerExpanded}}
          <div class="chat-drawer-content">
            <ChatPinnedMessagesList
              @channel={{@model.channel}}
              @pinnedMessages={{@model.pinnedMessages}}
            />
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
