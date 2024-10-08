import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";

const MORE_MENU = "sidebar-more-section";

export default class SidebarSectionLinkButton extends Component {
  @service menu;
  @service header;
  @service siteSettings;

  @action
  handleClick() {
    const menuInstance = this.menu.getByIdentifier(MORE_MENU);

    this.args.action();

    this.menu.close(menuInstance);

    if (this.args.toggleNavigationMenu) {
      this.args.toggleNavigationMenu();
    }

    if (this.siteSettings.navigation_menu === "header dropdown") {
      this.header.hamburgerVisible = false;
    }
  }

  <template>
    <div class="sidebar-section-link-wrapper">
      <button
        {{on "click" this.handleClick}}
        type="button"
        class="sidebar-section-link sidebar-row --link-button"
        data-list-item-name={{@text}}
      >
        <span class="sidebar-section-link-prefix icon">
          {{icon @icon}}
        </span>

        <span class="sidebar-section-link-content-text">
          {{@text}}
        </span>
      </button>
    </div>
  </template>
}
