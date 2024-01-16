import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

import concatClass from "discourse/helpers/concat-class";

const SidebarToggle = <template>
  <span class="header-sidebar-toggle">
    <DButton
      @title="sidebar.title"
      @icon="bars"
      class={{concatClass
        "btn btn-flat btn-sidebar-toggle"
        (if this.site.narrowDesktopView "narrow-desktop")
      }}
      aria-expanded={{if @showSidebar "true" "false"}}
      aria-controls="d-sidebar"
      @action={{@toggleHamburger}}
    />
  </span>
</template>;

export default SidebarToggle;
