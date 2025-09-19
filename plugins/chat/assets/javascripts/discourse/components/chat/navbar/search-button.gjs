import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";

const ChatNavbarSearchButton = <template>
  <input
    type="text"
    value={{this.filter}}
    {{on "input" (withEventValue @onFilter)}}
    placeholder="instructions"
    class="no-blur c-navbar__search"
  />
</template>;

export default ChatNavbarSearchButton;
