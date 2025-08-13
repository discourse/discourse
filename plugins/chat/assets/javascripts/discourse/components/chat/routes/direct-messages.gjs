import { i18n } from "discourse-i18n";
import ChannelsListDirect from "../../channels-list-direct";
import Navbar from "../navbar";

const ChatRoutesDirectMessages = <template>
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
</template>;

export default ChatRoutesDirectMessages;
