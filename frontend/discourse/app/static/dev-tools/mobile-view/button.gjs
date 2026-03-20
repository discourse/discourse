import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import mobile from "discourse/lib/mobile";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class MobileViewButton extends Component {
  get mobileViewActive() {
    return mobile.mobileView;
  }

  @action
  toggleMobileView() {
    mobile.toggleMobileView();
  }

  <template>
    <button
      title={{i18n "dev_tools.toggle_mobile_view"}}
      class={{dConcatClass
        "toggle-mobile-view"
        (if this.mobileViewActive "--active")
      }}
      {{on "click" this.toggleMobileView}}
    >
      {{dIcon "mobile-screen-button"}}
    </button>
  </template>
}
