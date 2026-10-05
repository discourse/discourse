import Component from "@glimmer/component";
import { service } from "@ember/service";
import MobileTabBarTabs from "discourse/components/mobile-tab-bar/tabs";
import { i18n } from "discourse-i18n";

export default class SidebarTabBar extends Component {
  @service mobileTabBar;

  <template>
    {{#if this.mobileTabBar.sidebarTabsEnabled}}
      <div
        aria-label={{i18n "mobile_tab_bar.label"}}
        class="mobile-tab-bar --sidebar"
        role="group"
      >
        <MobileTabBarTabs
          @ariaCurrent="true"
          @isActive={{this.mobileTabBar.isSidebarTabActive}}
          @onSelect={{this.mobileTabBar.selectSidebarTab}}
          @tabs={{this.mobileTabBar.sidebarTabs}}
        />
      </div>
    {{/if}}
  </template>
}
