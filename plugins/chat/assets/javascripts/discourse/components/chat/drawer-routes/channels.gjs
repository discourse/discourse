import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import ChannelsList from "discourse/plugins/chat/discourse/components/channels-list";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";

export default class ChatDrawerRoutesChannels extends Component {
  @service chatStateManager;

  <template>
    <Navbar as |navbar|>
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
