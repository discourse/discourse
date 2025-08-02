import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatRoutesThreads extends Component {
  @service site;

  <template>
    <div class="c-routes --threads">
      <Navbar as |navbar|>
        <navbar.Title @title={{i18n "chat.my_threads.title"}} />

        <navbar.Actions as |action|>
          <action.OpenDrawerButton />
        </navbar.Actions>
      </Navbar>

      <UserThreads />
    </div>
  </template>
}
