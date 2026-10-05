import Component from "@glimmer/component";
import { service } from "@ember/service";
import MobileTabBarTabs from "discourse/components/mobile-tab-bar/tabs";
import htmlClass from "discourse/helpers/html-class";
import { i18n } from "discourse-i18n";

export default class MobileTabBar extends Component {
  @service composer;
  @service mobileTabBar;

  get isVisible() {
    return this.mobileTabBar.enabled && !this.composer.isOpen;
  }

  <template>
    {{#if this.isVisible}}
      {{htmlClass "footer-nav-visible" "mobile-tab-bar-visible"}}

      <nav
        aria-label={{i18n "mobile_tab_bar.label"}}
        class="mobile-tab-bar --footer"
      >
        <MobileTabBarTabs
          @isActive={{this.mobileTabBar.isActive}}
          @onSelect={{this.mobileTabBar.selectTab}}
          @tabs={{this.mobileTabBar.tabs}}
        />
      </nav>
    {{/if}}
  </template>
}
