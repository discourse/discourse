import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const BackToForum = <template>
  <a href={{getURL "/"}} class="sidebar-sections__back-to-forum">
    {{icon "arrow-left"}}

    <span>{{i18n "sidebar.back_to_forum"}}</span>
  </a>
</template>;

export default BackToForum;
