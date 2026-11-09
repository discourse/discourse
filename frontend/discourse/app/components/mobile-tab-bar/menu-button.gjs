import Component from "@glimmer/component";
import { service } from "@ember/service";
import ReviewBadge from "discourse/components/mobile-tab-bar/review-badge";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class MobileTabBarMenuButton extends Component {
  @service currentUser;
  @service mobileTabBar;

  // Names the count shown over the icon, which the label would otherwise hide
  get ariaLabel() {
    const count = this.currentUser?.reviewable_count;

    return count
      ? i18n("mobile_tab_bar.menu_with_reviewables", { count })
      : i18n("mobile_tab_bar.menu");
  }

  <template>
    <DButton
      aria-expanded={{if this.mobileTabBar.isMenuOpen "true" "false"}}
      class="btn-transparent mobile-tab-bar__menu"
      @action={{this.mobileTabBar.toggleMenu}}
      @icon="bars"
      @title="mobile_tab_bar.menu"
      @translatedAriaLabel={{this.ariaLabel}}
    >
      {{! The menu leads to the review queue, whoever can review }}
      <span class="mobile-tab-bar__badge"><ReviewBadge /></span>
    </DButton>
  </template>
}
