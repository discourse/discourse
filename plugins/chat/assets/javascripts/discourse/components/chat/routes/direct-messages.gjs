import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChannelsListDirect from "discourse/plugins/chat/discourse/components/channels-list-direct";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";

export default class ChatRoutesDirectMessages extends Component {
  @service site;

  <template>
    <div class="c-routes --direct-messages">
      <Navbar as |navbar|>
        <navbar.Title @title={{i18n "chat.direct_messages.title"}} />
        <navbar.Actions as |action|>
          <action.OpenDrawerButton />
          <action.NewDirectMessageButton />
        </navbar.Actions>
      </Navbar>

      <ChannelsListDirect />
    </div>
  </template>
}
