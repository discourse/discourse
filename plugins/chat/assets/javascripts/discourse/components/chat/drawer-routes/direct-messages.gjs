import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";

export default class ChatDrawerRoutesDirectMessages extends Component {
  @service chat;
  @service chatStateManager;

  <template>
    <div class="c-drawer-routes --direct-messages">
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
          <ChannelsListDirect />
        </div>

        <ChatFooter />
      {{/if}}
    </div>
  </template>
}
