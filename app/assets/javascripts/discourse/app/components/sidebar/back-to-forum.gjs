import { LinkTo } from "@ember/routing";
import { defaultHomepage } from "discourse/lib/utilities";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

const BackToForum = <template>
  <LinkTo
    @route="discovery.{{(defaultHomepage)}}"
    class="sidebar-sections__back-to-forum"
  >
    {{icon "arrow-left"}}

    <span>{{i18n "sidebar.back_to_forum"}}</span>
  </LinkTo>
</template>;

export default BackToForum;
