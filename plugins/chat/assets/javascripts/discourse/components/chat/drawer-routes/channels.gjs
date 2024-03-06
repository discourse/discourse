import Component from "@glimmer/component";
import { service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import ChannelsList from "discourse/plugins/chat/discourse/components/channels-list";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";

export default class ChatDrawerRoutesChannels extends Component {
  @service chat;
  @service chatStateManager;

  <template>
    <Navbar @onClick={{this.chat.toggleDrawer}} as |navbar|>
      <navbar.Title @title={{i18n "chat.heading"}} />
      <navbar.Actions as |action|>
        <action.ToggleDrawerButton />
        <action.FullPageButton />
        <action.CloseDrawerButton />
      </navbar.Actions>
    </Navbar>

    {{#if this.chatStateManager.isDrawerExpanded}}
      <div class="chat-drawer-content">
        <ChannelsList />
      </div>
    {{/if}}
  </template>
}
