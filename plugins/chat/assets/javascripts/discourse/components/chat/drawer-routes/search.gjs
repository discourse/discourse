import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";
import ChatSearch from "discourse/plugins/chat/discourse/components/chat-search";

export default class ChatDrawerRoutesSearch extends Component {
  @service chat;
  @service chatStateManager;
  @service chatSearchQuery;

  <template>
    <div class="c-drawer-routes --search">
      <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
        <navbar.BackButton />
        <navbar.Title @title={{i18n "chat.search.title"}} />
        <navbar.Actions as |action|>
          <action.ToggleDrawerButton />
          <action.FullPageButton />
          <action.CloseDrawerButton />
        </navbar.Actions>
      </Navbar>

      {{#if this.chatStateManager.isDrawerExpanded}}
        <div class="chat-drawer-content">
          <ChatSearch
            @query={{this.chatSearchQuery.query}}
            @enableQueryParams={{false}}
          />
        </div>
      {{/if}}

      <ChatFooter />
    </div>
  </template>
}
