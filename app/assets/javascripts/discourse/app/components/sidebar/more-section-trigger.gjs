import { or } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MoreSectionTrigger = <template>
  <button ...attributes type="button" class="sidebar-section-link sidebar-row">
    <span class="sidebar-section-link-prefix icon">
      {{icon (or @componentArgs.data.moreIcon "ellipsis-vertical")}}
    </span>
    <span class="sidebar-section-link-content-text">
      {{or @componentArgs.data.moreText (i18n "sidebar.more")}}
    </span>
  </button>
</template>;

export default MoreSectionTrigger;
