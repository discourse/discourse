import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import ChatDrawerHeader from "discourse/plugins/chat/discourse/components/chat-drawer/header";
import ChatDrawerHeaderBackLink from "discourse/plugins/chat/discourse/components/chat-drawer/header/back-link";
import ChatDrawerHeaderRightActions from "discourse/plugins/chat/discourse/components/chat-drawer/header/right-actions";
import ChatDrawerHeaderTitle from "discourse/plugins/chat/discourse/components/chat-drawer/header/title";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatDrawerThreads extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  backLinkTitle = I18n.t("chat.return_to_list");

  <template>
    <ChatDrawerHeader @toggleExpand={{@drawerActions.toggleExpand}}>

      {{#if this.chatStateManager.isDrawerExpanded}}
        <div class="chat-drawer-header__left-actions">
          <div class="chat-drawer-header__top-line">
            <ChatDrawerHeaderBackLink
              @route="chat"
              @title={{this.backLink.title}}
            />
          </div>
        </div>
      {{/if}}

      <ChatDrawerHeaderTitle
        @title="chat.threads.list"
        @icon="discourse-threads"
        @channelName={{this.chat.activeChannel.title}}
      />

      <ChatDrawerHeaderRightActions @drawerActions={{@drawerActions}} />
    </ChatDrawerHeader>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div class="chat-drawer-content">
        <UserThreads />
      </div>
    {{/if}}
  </template>
}
