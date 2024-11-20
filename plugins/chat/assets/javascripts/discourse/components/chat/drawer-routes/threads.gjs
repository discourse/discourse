import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatDrawerRoutesThreads extends Component {
  @service chat;
  @service chatStateManager;

  <template>
    <div class="c-drawer-routes --threads">
      <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
        <navbar.Title @title={{i18n "chat.heading"}} />
        <navbar.Actions as |action|>
          <action.ThreadsListButton />
          <action.ToggleDrawerButton />
          <action.FullPageButton />
          <action.CloseDrawerButton />
        </navbar.Actions>
      </Navbar>

      {{#if this.chatStateManager.isDrawerExpanded}}
        <div class="chat-drawer-content">
          <UserThreads />
        </div>
      {{/if}}

      <ChatFooter />
    </div>
  </template>
}
