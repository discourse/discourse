import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { applyValueTransformer } from "discourse/lib/transformer";
import { prefersReducedMotion } from "discourse/lib/utilities";
import closeOnClickOutside from "../../modifiers/close-on-click-outside";
import SidebarHamburgerDropdown from "../sidebar/hamburger-dropdown";

const CLOSE_ON_CLICK_SELECTORS =
  "a[href], .sidebar-section-header-button, .sidebar-section-link:not(.--link-button)";

export default class HamburgerDropdownWrapper extends Component {
  @service navigationMenu;

  @action
  toggleNavigation() {
    this.args.toggleNavigationMenu(
      this.navigationMenu.isDesktopDropdownMode ? "hamburger" : null
    );
  }

  @action
  click(e) {
    if (e.target.closest(CLOSE_ON_CLICK_SELECTORS)) {
      this.toggleNavigation();
    }
  }

  @action
  clickOutside(e) {
    let exceptionSelectors = [".sidebar-more-section-content"];

    exceptionSelectors = applyValueTransformer(
      "hamburger-dropdown-click-outside-exceptions",
      exceptionSelectors,
      { event: e }
    );

    if (exceptionSelectors.some((selector) => e.target.closest(selector))) {
      return;
    }

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
            this.toggleNavigation();
          } else {
            discourseLater(() => this.toggleNavigation());
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
      this.toggleNavigation();
    }
  }

  get forceMainSidebarPanel() {
    // NOTE: In this scenario, we are forcing the sidebar to be shown
    // when the navigation mode is hamburger. We still need to show the
    // main panel in the hamburger menu, regardless of what is in the sidebar.
    if (this.args.sidebarEnabled && this.navigationMenu.isDesktopDropdownMode) {
      return true;
    }

    return false;
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
      ...attributes
    >
      <SidebarHamburgerDropdown
        @forceMainSidebarPanel={{this.forceMainSidebarPanel}}
        @toggleNavigationMenu={{this.toggleNavigation}}
      />
    </div>
  </template>
}
