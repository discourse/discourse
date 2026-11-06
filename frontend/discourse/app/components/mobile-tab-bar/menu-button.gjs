import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class MobileTabBarMenuButton extends Component {
  @service mobileTabBar;

  <template>
    <DButton
      aria-expanded={{if this.mobileTabBar.isMenuOpen "true" "false"}}
      class="btn-transparent mobile-tab-bar__menu"
      @action={{this.mobileTabBar.toggleMenu}}
      @ariaLabel="mobile_tab_bar.menu"
      @icon="bars"
      @title="mobile_tab_bar.menu"
    />
  </template>
}
