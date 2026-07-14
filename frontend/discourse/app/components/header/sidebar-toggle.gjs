import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SidebarToggle extends Component {
  @service site;
  @service navigationMenu;

  @action
  toggle() {
    const wasHidden = !this.args.showSidebar;

    if (this.navigationMenu.isDesktopDropdownMode) {
      this.args.toggleNavigationMenu("sidebar");
    } else {
      this.args.toggleNavigationMenu();
    }

    if (wasHidden) {
      schedule("afterRender", () => {
        document.querySelector("#d-sidebar a, #d-sidebar button")?.focus();
      });
    }
  }

  <template>
    <span class="header-sidebar-toggle">
      <button
        title={{i18n "sidebar.title"}}
        class={{dConcatClass
          "btn btn-flat btn-sidebar-toggle no-text btn-icon"
          (if this.site.narrowDesktopView "narrow-desktop")
        }}
        aria-expanded={{if @showSidebar "true" "false"}}
        aria-controls="d-sidebar"
        {{on "click" this.toggle}}
      >
        {{dIcon @icon}}
      </button>
    </span>
  </template>
}
