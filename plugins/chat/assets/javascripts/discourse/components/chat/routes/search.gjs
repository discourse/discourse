import { i18n } from "discourse-i18n";
import ChatSearch from "../../chat-search";
import Navbar from "../navbar";

const ChatRoutesSearch = <template>
  <div class="c-routes --search">
    <Navbar as |navbar|>
      <navbar.BackButton />
      <navbar.Title @title={{i18n "chat.search.title"}} />
      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
      </navbar.Actions>
    </Navbar>
    <ChatSearch @query={{@query}} />
  </div>
</template>;

export default ChatRoutesSearch;
