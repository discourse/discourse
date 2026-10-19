import { i18n } from "discourse-i18n";
import UserThreads from "../../user-threads/index.gjs";
import Navbar from "../navbar/index.gjs";

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
