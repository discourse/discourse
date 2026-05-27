import { i18n } from "discourse-i18n";
import ChannelsListPublic from "../../channels-list-public";
import Navbar from "../navbar";

const ChatRoutesChannels = <template>
  <div class="c-routes --channels">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.chat_channels"}} />
      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
        <action.BrowseChannelsButton />
      </navbar.Actions>
    </Navbar>

    <ChannelsListPublic />
  </div>
</template>;

export default ChatRoutesChannels;
