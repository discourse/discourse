import { i18n } from "discourse-i18n";
import ChatSearch from "../../chat-search.gjs";
import Navbar from "../navbar/index.gjs";

const ChatRoutesSearch = <template>
  <div class="c-routes --search">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.search.title"}} />
      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
      </navbar.Actions>
    </Navbar>
    <ChatSearch @query={{@query}} />
  </div>
</template>;

export default ChatRoutesSearch;
