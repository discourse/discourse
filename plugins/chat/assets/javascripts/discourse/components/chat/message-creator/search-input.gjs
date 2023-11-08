import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import icon from "discourse-common/helpers/d-icon";

export default class ChatMessageCreatorSearchInput extends Component {
  <template>
    <div class="chat-message-creator__search-input-container">
      <div class="chat-message-creator__search-input">
        {{icon
          "search"
          class="chat-message-creator__search-input__search-icon"
        }}
        <Input
          class="chat-message-creator__search-input__input"
          placeholder="Filter"
          {{on "input" @onFilter}}
        />
      </div>
    </div>
  </template>
}
