import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The tabs past the bar's room, in a sheet. It's highlighted like a tab while
// one of its sections is current, so the views above point at it then.
export default class MobileTabBarMoreTab extends Component {
  @service mobileTabBar;

  @action
  select(key, menu) {
    menu.close();
    this.mobileTabBar.selectTab(key);
  }

  <template>
    <DMenu
      aria-current={{if this.mobileTabBar.isMoreActive "page"}}
      class={{dConcatClass
        "btn-transparent mobile-tab-bar__tab mobile-tab-bar__more"
        (if this.mobileTabBar.isMoreActive "--active")
      }}
      data-key="more"
      @ariaLabel={{i18n "mobile_tab_bar.more"}}
      @identifier="mobile-tab-bar-more"
      @modalForMobile={{true}}
    >
      <:trigger>
        <span class="mobile-tab-bar__indicator">
          {{dIcon "ellipsis"}}
          {{! Shows what's new in its sections, as their tabs would }}
          <span class="mobile-tab-bar__badge">
            {{#each this.mobileTabBar.moreTabs key="key" as |tab|}}
              {{#if tab.badgeComponent}}
                <tab.badgeComponent />
              {{/if}}
            {{/each}}
          </span>
        </span>
        <span class="mobile-tab-bar__label sr-only">{{i18n
            "mobile_tab_bar.more"
          }}</span>
      </:trigger>
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#each this.mobileTabBar.moreTabs key="key" as |tab|}}
            <dropdown.item>
              <DButton
                aria-current={{if (this.mobileTabBar.isActive tab) "page"}}
                class={{dConcatClass
                  "btn-transparent mobile-tab-bar__more-item"
                  (if (this.mobileTabBar.isActive tab) "--active")
                }}
                data-key={{tab.key}}
                @action={{fn this.select tab.key menu}}
                @icon={{tab.icon}}
                @translatedLabel={{tab.label}}
              >
                {{#if tab.badgeComponent}}
                  <span class="mobile-tab-bar__more-badge">
                    <tab.badgeComponent />
                  </span>
                {{/if}}
              </DButton>
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
