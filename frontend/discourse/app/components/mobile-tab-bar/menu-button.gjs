import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class MobileTabBarMenuButton extends Component {
  @service mobileTabBar;

  <template>
    <DButton
      aria-expanded={{if this.mobileTabBar.isMenuOpen "true" "false"}}
      class="btn-transparent mobile-tab-bar__menu"
      @action={{this.mobileTabBar.toggleMenu}}
      @icon="bars"
      @translatedAriaLabel={{i18n "mobile_tab_bar.menu"}}
      @translatedTitle={{i18n "mobile_tab_bar.menu"}}
    />
  </template>
}
