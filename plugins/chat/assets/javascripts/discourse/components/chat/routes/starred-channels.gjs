import { i18n } from "discourse-i18n";
import ChannelsListStarred from "../../channels-list-starred";
import Navbar from "../navbar";

const ChatRoutesStarredChannels = <template>
  <div class="c-routes --starred-channels">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.starred"}} />
      <navbar.Actions as |action|>

        <action.OpenDrawerButton />
      </navbar.Actions>
    </Navbar>

    <ChannelsListStarred />
  </div>
</template>;

export default ChatRoutesStarredChannels;
