import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import i18n from "discourse-common/helpers/i18n";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";
import ChannelsListPublic from "discourse/plugins/chat/discourse/components/channels-list-public";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatDrawerRoutesChannels extends Component {
  @service chat;
  @service chatStateManager;

  @tracked activeTab = "channels";

  @action
  onClickTab(tab) {
    this.activeTab = tab;
  }

  <template>
    <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
      <navbar.Title @title={{i18n "chat.heading"}} />
      <navbar.Actions as |a|>
        <a.ToggleDrawerButton />
        <a.FullPageButton />
        <a.CloseDrawerButton />
      </navbar.Actions>
    </Navbar>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div class="chat-drawer-content">
        {{#if (eq this.activeTab "channels")}}
          <ChannelsListPublic />
        {{else if (eq this.activeTab "direct-messages")}}
          <ChannelsListDirect />
        {{else if (eq this.activeTab "threads")}}
          <UserThreads />
        {{/if}}
      </div>

      <ChatFooter
        @activeTab={{this.activeTab}}
        @onClickTab={{this.onClickTab}}
      />
    {{/if}}
  </template>
}
