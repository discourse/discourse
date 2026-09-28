import Component from "@glimmer/component";
import { service } from "@ember/service";
import htmlClass from "discourse/helpers/html-class";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class HeaderSectionNavButton extends Component {
  @service mobileTabBar;

  <template>
    {{#if this.mobileTabBar.isNestedPage}}
      {{htmlClass "mobile-tab-bar-nested"}}
    {{/if}}
    <ul class="d-header-icons header-section-nav">
      <li class="header-dropdown-toggle">
        <DButton
          aria-expanded={{if
            this.mobileTabBar.isSectionMenuOpen
            "true"
            "false"
          }}
          class="icon btn-flat"
          @action={{this.mobileTabBar.toggleSectionMenu}}
          @icon="bars"
          @translatedAriaLabel={{i18n "mobile_tab_bar.menu"}}
          @translatedTitle={{i18n "mobile_tab_bar.menu"}}
        />
      </li>
    </ul>
  </template>
}
