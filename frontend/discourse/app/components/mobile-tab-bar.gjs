import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import htmlClass from "discourse/helpers/html-class";
import { MORE_TAB } from "discourse/lib/mobile-tab-bar";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const TabContent = <template>
  <span class="mobile-tab-bar__indicator">
    {{dIcon @tab.icon}}
    {{#if @tab.badgeComponent}}
      <span class="mobile-tab-bar__badge"><@tab.badgeComponent /></span>
    {{/if}}
  </span>
  <span class="mobile-tab-bar__label">{{@tab.label}}</span>
</template>;

export default class MobileTabBar extends Component {
  @service composer;
  @service mobileTabBar;

  get isVisible() {
    return this.mobileTabBar.enabled && !this.composer.isOpen;
  }

  @action
  selectHeldTab(key, menu) {
    menu.close();
    this.mobileTabBar.selectTab(key);
  }

  <template>
    {{#if this.isVisible}}
      {{htmlClass "footer-nav-visible" "mobile-tab-bar-visible"}}

      <nav aria-label={{i18n "mobile_tab_bar.label"}} class="mobile-tab-bar">
        {{#each this.mobileTabBar.tabs key="key" as |tab|}}
          {{#if (eq tab.key MORE_TAB)}}
            <DMenu
              data-key={{tab.key}}
              @identifier="mobile-tab-bar-more"
              @modalForMobile={{true}}
              @triggerClass={{dConcatClass
                "btn-transparent mobile-tab-bar__tab"
                (if (this.mobileTabBar.isActive tab) "--active")
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
                        class="btn-transparent mobile-tab-bar__held-tab"
                        data-key={{held.key}}
                        @action={{fn this.selectHeldTab held.key menu}}
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
              aria-current={{if (this.mobileTabBar.isActive tab) "page"}}
              class={{dConcatClass
                "btn-transparent mobile-tab-bar__tab"
                (if (this.mobileTabBar.isActive tab) "--active")
              }}
              data-key={{tab.key}}
              @action={{fn this.mobileTabBar.selectTab tab.key}}
            >
              <TabContent @tab={{tab}} />
            </DButton>
          {{/if}}
        {{/each}}
      </nav>
    {{/if}}
  </template>
}
