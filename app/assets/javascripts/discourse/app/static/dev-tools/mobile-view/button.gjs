import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import mobile from "discourse/lib/mobile";

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
      title="Toggle mobile view"
      class={{concatClass
        "toggle-mobile-view"
        (if this.mobileViewActive "--active")
      }}
      {{on "click" this.toggleMobileView}}
    >
      {{icon "mobile-screen-button"}}
    </button>
  </template>
}
