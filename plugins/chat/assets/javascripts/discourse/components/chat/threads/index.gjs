import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatThreads extends Component {
  <template>
    <div class="chat-threads">
      <Navbar>
        <:current>
          {{icon "discourse-threads"}}
          {{i18n "chat.my_threads.title"}}
        </:current>
      </Navbar>

      <UserThreads />
    </div>
  </template>
}
