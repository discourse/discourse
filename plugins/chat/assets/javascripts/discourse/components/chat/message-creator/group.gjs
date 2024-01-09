import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";

export default class ChatableGroup extends Component {
  @service currentUser;

  <template>
    <div class="chat-message-creator__chatable -group">
      <div class="chat-message-creator__group-icon">
        {{icon "user-friends"}}
      </div>
      <div class="chat-message-creator__group-name">
        {{@item.model.name}}
      </div>
    </div>
  </template>
}
