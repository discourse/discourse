import { i18n } from "discourse-i18n";
import ChannelsListPublic from "../../channels-list-public.gjs";
import ChannelListOptionsButton from "../navbar/channel-list-options-button.gjs";
import Navbar from "../navbar/index.gjs";

const ChatRoutesChannels = <template>
  <div class="c-routes --channels">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.chat_channels"}} />
      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
        <ChannelListOptionsButton @section="channels" />
      </navbar.Actions>
    </Navbar>

    <ChannelsListPublic />
  </div>
</template>;

export default ChatRoutesChannels;
