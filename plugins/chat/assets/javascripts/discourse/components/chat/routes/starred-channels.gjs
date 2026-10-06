import { i18n } from "discourse-i18n";
import ChannelsListStarred from "../../channels-list-starred";
import Navbar from "../navbar";
import ChannelListOptionsButton from "../navbar/channel-list-options-button";

const ChatRoutesStarredChannels = <template>
  <div class="c-routes --starred-channels">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.starred"}} />
      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
        <ChannelListOptionsButton @section="starred" />
      </navbar.Actions>
    </Navbar>

    <ChannelsListStarred />
  </div>
</template>;

export default ChatRoutesStarredChannels;
