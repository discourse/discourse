import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import discourseLater from "discourse/lib/later";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { prefersReducedMotion } from "discourse/lib/utilities";
import { isTesting } from "discourse-common/config/environment";
import closeOnClickOutside from "../../modifiers/close-on-click-outside";
import UserMenu from "../user-menu/menu";

export default class UserMenuWrapper extends Component {
  @action
  clickOutside(e) {
    if (
      e.target.classList.contains("header-cloak") &&
      !prefersReducedMotion()
    ) {
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      const finishPosition = isDocumentRTL() ? "-340px" : "340px";
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
      {{closeOnClickOutside
        this.clickOutside
        (hash
          targetSelector=".user-menu-panel"
          secondaryTargetSelector=".user-menu-panel"
        )
      }}
      ...attributes
    >
      <UserMenu @closeUserMenu={{@toggleUserMenu}} />
    </div>
  </template>
}
