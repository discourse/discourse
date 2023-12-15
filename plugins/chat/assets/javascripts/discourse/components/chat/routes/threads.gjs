import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";
import UserThreads from "discourse/plugins/chat/discourse/components/user-threads";

export default class ChatRoutesThreads extends Component {
  <template>
    <div class="c-routes-threads">
      <Navbar as |navbar|>
        <navbar.BackButton />
        <navbar.Title
          @title={{i18n "chat.my_threads.title"}}
          @icon="discourse-threads"
        />

        <navbar.Actions as |action|>
          <action.OpenDrawerButton />
        </navbar.Actions>
      </Navbar>

      <UserThreads />
    </div>
  </template>
}
