import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class MobileTabBarTab extends Component {
  @service mobileTabBar;

  get isActive() {
    return this.mobileTabBar.isActive(this.args.tab);
  }

  <template>
    <DButton
      aria-current={{if this.isActive "page"}}
      class={{dConcatClass
        "btn-transparent mobile-tab-bar__tab"
        (if this.isActive "--active")
      }}
      data-key={{@tab.key}}
      @action={{fn this.mobileTabBar.selectTab @tab.key}}
    >
      <span class="mobile-tab-bar__indicator">
        {{dIcon @tab.icon}}
        {{#if @tab.badgeComponent}}
          <span class="mobile-tab-bar__badge"><@tab.badgeComponent /></span>
        {{/if}}
      </span>
      <span class="mobile-tab-bar__label">{{@tab.label}}</span>
    </DButton>
  </template>
}
