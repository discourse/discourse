import { fn } from "@ember/helper";
import DMenu from "discourse/float-kit/components/d-menu";
import { MORE_TAB } from "discourse/lib/mobile-tab-bar";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const TabContent = <template>
  <span class="mobile-tab-bar__indicator">
    {{dIcon @tab.icon}}
    {{#if @tab.badgeComponent}}
      <span class="mobile-tab-bar__badge"><@tab.badgeComponent /></span>
    {{/if}}
  </span>
  <span class="mobile-tab-bar__label">{{@tab.label}}</span>
</template>;

function selectHeldTab(onSelect, key, menu) {
  menu.close();
  onSelect(key);
}

/**
 * The tabs of a tab bar, with a "More" menu for any tabs it holds.
 *
 * @param {Array<Object>} tabs As arranged by `arrangeTabs`.
 * @param {(tab: Object) => boolean} isActive
 * @param {(key: string) => void} onSelect
 * @param {string} [ariaCurrent] What the active tab marks as current.
 */
const MobileTabBarTabs = <template>
  {{#each @tabs key="key" as |tab|}}
    {{#if (eq tab.key MORE_TAB)}}
      <DMenu
        data-key={{tab.key}}
        @identifier="mobile-tab-bar-more"
        @modalForMobile={{true}}
        @triggerClass={{dConcatClass
          "btn-transparent mobile-tab-bar__tab"
          (if (@isActive tab) "--active")
        }}
      >
        <:trigger>
          <TabContent @tab={{tab}} />
        </:trigger>
        <:content as |menu|>
          <DDropdownMenu as |dropdown|>
            {{#each tab.overflow key="key" as |held|}}
              <dropdown.item>
                <DButton
                  class={{dConcatClass
                    "btn-transparent mobile-tab-bar__held-tab"
                    (if (@isActive held) "--active")
                  }}
                  data-key={{held.key}}
                  @action={{fn selectHeldTab @onSelect held.key menu}}
                  @icon={{held.icon}}
                  @translatedLabel={{held.label}}
                />
              </dropdown.item>
            {{/each}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{else}}
      <DButton
        aria-current={{if (@isActive tab) (or @ariaCurrent "page")}}
        class={{dConcatClass
          "btn-transparent mobile-tab-bar__tab"
          (if (@isActive tab) "--active")
        }}
        data-key={{tab.key}}
        @action={{fn @onSelect tab.key}}
      >
        <TabContent @tab={{tab}} />
      </DButton>
    {{/if}}
  {{/each}}
</template>;

export default MobileTabBarTabs;
