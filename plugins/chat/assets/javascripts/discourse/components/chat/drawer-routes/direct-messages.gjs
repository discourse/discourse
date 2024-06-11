import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import i18n from "discourse-common/helpers/i18n";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";

export default class ChatDrawerRoutesChannels extends Component {
  @service chat;
  @service chatStateManager;

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
        <ChannelsListDirect />
      </div>

      <ChatFooter />
    {{/if}}
  </template>
}
