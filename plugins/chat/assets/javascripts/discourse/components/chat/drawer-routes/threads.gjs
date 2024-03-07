import Component from "@glimmer/component";
import { service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatDrawerRoutesThreads extends Component {
  @service chat;
  @service chatStateManager;

  backButtonTitle = I18n.t("chat.return_to_list");

  <template>
    <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
      <navbar.BackButton @title={{this.backButtonTitle}} />
      <navbar.Title
        @title={{i18n "chat.my_threads.title"}}
        @icon="discourse-threads"
      />
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
  </template>
}
