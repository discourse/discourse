import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";

const ChatNavbarSearchButton = <template>
  <LinkTo
    @route="chat.channel.info.search"
    @models={{@channel.routeModels}}
    title="TODO search"
    class="c-navbar__search-button btn no-text btn-transparent"
  >
    {{icon "magnifying-glass"}}
  </LinkTo>
</template>;

export default ChatNavbarSearchButton;
