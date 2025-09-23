import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

const ChatNavbarSearchButton = <template>
  <input
    type="text"
    value={{this.filter}}
    {{on "input" (withEventValue @onFilter)}}
    placeholder={{i18n "chat.search_view.filter_placeholder"}}
    class="no-blur c-navbar__search"
  />
</template>;

export default ChatNavbarSearchButton;
