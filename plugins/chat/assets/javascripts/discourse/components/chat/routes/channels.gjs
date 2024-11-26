import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChannelsListPublic from "discourse/plugins/chat/discourse/components/channels-list-public";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";

export default class ChatRoutesChannels extends Component {
  @service site;

  <template>
    <div class="c-routes --channels">
      <Navbar as |navbar|>
        <navbar.Title @title={{i18n "chat.chat_channels"}} />
        <navbar.Actions as |action|>
          <action.OpenDrawerButton />
          <action.BrowseChannelsButton />
        </navbar.Actions>
      </Navbar>

      <ChannelsListPublic @sortByActivity={{true}} />
    </div>
  </template>
}
