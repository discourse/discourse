import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { waitForPromise } from "@ember/test-waiters";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { prefersReducedMotion } from "discourse/lib/utilities";
import { isTesting } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";
import closeOnClickOutside from "../../modifiers/close-on-click-outside";
import HamburgerDropdown from "../sidebar/hamburger-dropdown";

const CLOSE_ON_CLICK_SELECTORS =
  "a[href], .sidebar-section-header-button, .--link-button, .sidebar-section-link";

export default class HamburgerDropdownWrapper extends Component {
  @action
  click(e) {
    if (e.target.closest(CLOSE_ON_CLICK_SELECTORS)) {
      this.args.toggleHamburger();
    }
  }

  @action
  clickOutside(e) {
    if (
      e.target.classList.contains("header-cloak") &&
      !prefersReducedMotion()
    ) {
      const panel = document.querySelector(".menu-panel");
      const headerCloak = document.querySelector(".header-cloak");
      const finishPosition = isDocumentRTL() ? "340px" : "-340px";
      const panelAnimatePromise = panel
        .animate([{ transform: `translate3d(${finishPosition}, 0, 0)` }], {
          duration: isTesting() ? 0 : 200,
          fill: "forwards",
          easing: "ease-in",
        })
        .finished.then(() => {
          if (isTesting()) {
            this.args.toggleHamburger();
          } else {
            discourseLater(() => this.args.toggleHamburger());
          }
        });
      const cloakAnimatePromise = headerCloak.animate([{ opacity: 0 }], {
        duration: isTesting() ? 0 : 200,
        fill: "forwards",
        easing: "ease-in",
      }).finished;
      waitForPromise(panelAnimatePromise);
      waitForPromise(cloakAnimatePromise);
    } else {
      this.args.toggleHamburger();
    }
  }
  <template>
    <div
      class="hamburger-dropdown-wrapper"
      {{! template-lint-disable no-invalid-interactive }}
      {{on "click" this.click}}
      {{! we don't want to close the hamburger dropdown when clicking on the hamburger dropdown itself
        so we use the secondaryTargetSelector to prevent that }}
      {{closeOnClickOutside
        this.clickOutside
        (hash
          targetSelector=".hamburger-panel"
          secondaryTargetSelector=".hamburger-dropdown"
        )
      }}
    >
      <HamburgerDropdown />
    </div>
  </template>
}
