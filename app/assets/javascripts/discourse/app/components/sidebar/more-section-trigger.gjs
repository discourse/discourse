import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MoreSectionTrigger = <template>
  <button ...attributes type="button" class="sidebar-section-link sidebar-row">
    <span class="sidebar-section-link-prefix icon">
      {{icon "ellipsis-vertical"}}
    </span>
    <span class="sidebar-section-link-content-text">
      {{i18n "sidebar.more"}}
    </span>
  </button>
</template>;

export default MoreSectionTrigger;
