import { on } from "@ember/modifier";
import icon from "discourse-common/helpers/d-icon";

const SidebarSectionLinkButton = <template>
  <div class="sidebar-section-link-wrapper">
    <button
      {{on "click" @action}}
      type="button"
      class="sidebar-section-link sidebar-row --link-button"
    >
      <span class="sidebar-section-link-prefix icon">
        {{icon @icon}}
      </span>

      <span class="sidebar-section-link-content-text">
        {{@text}}
      </span>
    </button>
  </div>
</template>;

export default SidebarSectionLinkButton;
