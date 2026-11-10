import { i18n } from "discourse-i18n";
import ChannelsListDirect from "../../channels-list-direct.gjs";
import ChannelListOptionsButton from "../navbar/channel-list-options-button.gjs";
import Navbar from "../navbar/index.gjs";

const ChatRoutesDirectMessages = <template>
  <div class="c-routes --direct-messages">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.direct_messages.title"}} />
      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
        <ChannelListOptionsButton @section="dms" />
      </navbar.Actions>
    </Navbar>

    <ChannelsListDirect />
  </div>
</template>;

export default ChatRoutesDirectMessages;
