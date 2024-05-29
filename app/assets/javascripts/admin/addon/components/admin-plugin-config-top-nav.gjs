import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import NavItem from "discourse/components/nav-item";
import i18n from "discourse-common/helpers/i18n";

export default class AdminPluginConfigTopNav extends Component {
  @service adminPluginNavManager;

  linkText(navLink) {
    if (navLink.label) {
      return i18n(navLink.label);
    } else {
      return navLink.text;
    }
  }

  <template>
    <div class="admin-nav-submenu">
      <HorizontalOverflowNav
        class="plugin-nav admin-plugin-config-page__top-nav"
      >
        {{#each this.adminPluginNavManager.currentConfigNav.links as |navLink|}}
          <NavItem
            @route={{navLink.route}}
            @i18nLabel={{this.linkText navLink}}
            title={{this.linkText navLink}}
            class="admin-plugin-config-page__top-nav-item"
          >
            {{this.linkText navLink}}
          </NavItem>
        {{/each}}
      </HorizontalOverflowNav>
    </div>
  </template>
}
