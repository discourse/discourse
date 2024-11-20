import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatMessageCreatorSearchInput extends Component {
  filterPlaceholder = i18n("chat.new_message_modal.filter");

  <template>
    <div class="chat-message-creator__search-input-container">
      <div class="chat-message-creator__search-input">
        {{icon
          "magnifying-glass"
          class="chat-message-creator__search-input__search-icon"
        }}
        <Input
          class="chat-message-creator__search-input__input"
          placeholder={{this.filterPlaceholder}}
          {{on "input" @onFilter}}
        />
      </div>
    </div>
  </template>
}
