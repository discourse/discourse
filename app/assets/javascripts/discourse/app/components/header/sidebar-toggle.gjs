import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SidebarToggle extends Component {
  @service site;
  @service sidebarState;

  @action
  toggleWithBlur(e) {
    if (this.sidebarState.adminSidebarAllowedWithLegacyNavigationMenu) {
      this.args.toggleNavigationMenu("sidebar");
    } else {
      this.args.toggleNavigationMenu();
    }

    // remove the focus of the header dropdown button after clicking
    e.target.tagName.toLowerCase() === "button"
      ? e.target.blur()
      : e.target.closest("button").blur();
  }

  <template>
    <span class="header-sidebar-toggle">
      <button
        title={{i18n "sidebar.title"}}
        class={{concatClass
          "btn btn-flat btn-sidebar-toggle no-text btn-icon"
          (if this.site.narrowDesktopView "narrow-desktop")
        }}
        aria-expanded={{if @showSidebar "true" "false"}}
        aria-controls="d-sidebar"
        {{on "click" this.toggleWithBlur}}
      >
        {{icon @icon}}
      </button>
    </span>
  </template>
}
