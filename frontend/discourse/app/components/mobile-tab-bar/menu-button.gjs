import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class MobileTabBarMenuButton extends Component {
  @service currentUser;
  @service mobileTabBar;

  get ariaLabel() {
    const count = this.currentUser?.reviewable_count;

    return count
      ? i18n("mobile_tab_bar.menu_with_reviewables", { count })
      : i18n("mobile_tab_bar.menu");
  }

  <template>
    <DButton
      aria-expanded={{if this.mobileTabBar.isMenuOpen "true" "false"}}
      class="btn-default mobile-tab-bar__menu"
      @action={{this.mobileTabBar.toggleMenu}}
      @icon="bars"
      @title="mobile_tab_bar.menu"
      @translatedAriaLabel={{this.ariaLabel}}
    >
      {{#if this.currentUser.reviewable_count}}
        <span class="mobile-tab-bar__badge">
          <span class="mobile-tab-bar__count">
            {{this.currentUser.reviewable_count}}
          </span>
        </span>
      {{/if}}
    </DButton>
  </template>
}
