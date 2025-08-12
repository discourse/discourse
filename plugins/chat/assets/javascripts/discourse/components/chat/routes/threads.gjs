import { i18n } from "discourse-i18n";
import UserThreads from "../../user-threads";
import Navbar from "../navbar";

const ChatRoutesThreads = <template>
  <div class="c-routes --threads">
    <Navbar as |navbar|>
      <navbar.Title @title={{i18n "chat.my_threads.title"}} />

      <navbar.Actions as |action|>
        <action.OpenDrawerButton />
      </navbar.Actions>
    </Navbar>

    <UserThreads />
  </div>
</template>;

export default ChatRoutesThreads;
