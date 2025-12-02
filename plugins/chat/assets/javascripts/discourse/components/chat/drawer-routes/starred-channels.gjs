import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChannelsListStarred from "discourse/plugins/chat/discourse/components/channels-list-starred";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ManageStarredButton from "discourse/plugins/chat/discourse/components/chat/navbar/manage-starred-button";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";

export default class ChatDrawerRoutesStarredChannels extends Component {
  @service chat;
  @service chatStateManager;

  <template>
    <div class="c-drawer-routes --starred-channels">
      <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
        <navbar.Title @title={{i18n "chat.starred"}} />
        <navbar.Actions as |a|>
          <ManageStarredButton />
          <a.SearchButton />
          <a.ToggleDrawerButton />
          <a.FullPageButton />
          <a.CloseDrawerButton />
        </navbar.Actions>
      </Navbar>

      {{#if this.chatStateManager.isDrawerExpanded}}
        <div class="chat-drawer-content">
          <ChannelsListStarred />
        </div>

        <ChatFooter />
      {{/if}}
    </div>
  </template>
}
