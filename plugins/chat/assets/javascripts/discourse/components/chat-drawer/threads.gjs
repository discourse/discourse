import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import I18n from "discourse-i18n";
import and from "truth-helpers/helpers/and";
import ChatDrawerHeader from "discourse/plugins/chat/discourse/components/chat-drawer/header";
import ChatDrawerHeaderBackLink from "discourse/plugins/chat/discourse/components/chat-drawer/header/back-link";
import ChatDrawerHeaderRightActions from "discourse/plugins/chat/discourse/components/chat-drawer/header/right-actions";
import ChatDrawerHeaderTitle from "discourse/plugins/chat/discourse/components/chat-drawer/header/title";
import ChatThreadList from "discourse/plugins/chat/discourse/components/chat-thread-list";

export default class ChatDrawerThreads extends Component {
  @service appEvents;
  @service chat;
  @service chatStateManager;
  @service chatChannelsManager;

  backLinkTitle = I18n.t("chat.return_to_list");

  @action
  fetchChannel() {
    if (!this.args.params?.channelId) {
      return;
    }

    return this.chatChannelsManager
      .find(this.args.params.channelId)
      .then((channel) => {
        this.chat.activeChannel = channel;
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
              @route="chat.channel"
              @title={{this.backLinkTitle}}
              @routeModels={{this.chat.activeChannel.routeModels}}
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
      <div class="chat-drawer-content" {{didInsert this.fetchChannel}}>
        {{#if this.chat.activeChannel}}
          <ChatThreadList
            @channel={{this.chat.activeChannel}}
            @includeHeader={{false}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
