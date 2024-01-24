import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import CloseOnClickOutside from "../../modifiers/close-on-click-outside";
import { modifier } from "ember-modifier";
import { hash } from "@ember/helper";
import { isTesting } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";
import UserMenu from "../user-menu/menu";

export default class UserMenuWrapper extends Component {
  @action
  clickOutside(e) {
    if (
      e.target.classList.contains("header-cloak") &&
      !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      const finishPosition =
        document.querySelector("html").classList["direction"] === "rtl"
          ? "-340px"
          : "340px";
      panel
        .animate([{ transform: `translate3d(${finishPosition}, 0, 0)` }], {
          duration: 200,
          fill: "forwards",
          easing: "ease-in",
        })
        .finished.then(() => {
          if (isTesting()) {
            this.args.toggleUserMenu();
          } else {
            discourseLater(() => this.args.toggleUserMenu());
          }
        });
      headerCloak.animate([{ opacity: 0 }], {
        duration: 200,
        fill: "forwards",
        easing: "ease-in",
      });
    } else {
      this.args.toggleUserMenu();
    }
  }

  <template>
    <div
      class="user-menu-dropdown-wrapper"
      {{(modifier
        CloseOnClickOutside
        this.clickOutside
        (hash
          targetSelector=".user-menu-panel"
          secondaryTargetSelector=".user-menu-panel"
        )
      )}}
    >
      <UserMenu @closeUserMenu={{@toggleUserMenu}} />
    </div>
  </template>
}
