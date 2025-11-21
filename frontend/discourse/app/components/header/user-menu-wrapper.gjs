import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { waitForPromise } from "@ember/test-waiters";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { prefersReducedMotion } from "discourse/lib/utilities";
import closeOnClickOutside from "../../modifiers/close-on-click-outside";
import UserMenu from "../user-menu/menu";

export default class UserMenuWrapper extends Component {
  @service site;

  @tracked userMenuWrapper;

  @action
  async clickOutside(e) {
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
      if (!prefersReducedMotion()) {
        try {
          if (this.site.desktopView) {
            await this.#animateMenu();
          }
        } finally {
          this.args.toggleUserMenu();
        }
      } else {
        this.args.toggleUserMenu();
      }
    }
  }

  @action
  async setupWrapper(el) {
    this.userMenuWrapper = el.querySelector(".menu-panel.drop-down");
  }

  async #animateMenu() {
    this.userMenuWrapper.classList.add("-closing");

    await waitForPromise(
      Promise.all([this.#waitForAnimationEnd(this.userMenuWrapper)])
    );
  }

  #waitForAnimationEnd(el) {
    return new Promise((resolve) => {
      const style = window.getComputedStyle(el);
      const duration = parseFloat(style.animationDuration) * 1000 || 0;
      const delay = parseFloat(style.animationDelay) * 1000 || 0;
      const totalTime = duration + delay;

      const timeoutId = setTimeout(
        () => {
          el.removeEventListener("animationend", handleAnimationEnd);
          resolve();
        },
        Math.max(totalTime + 50, 50)
      );

      const handleAnimationEnd = () => {
        clearTimeout(timeoutId);
        el.removeEventListener("animationend", handleAnimationEnd);
        resolve();
      };

      el.addEventListener("animationend", handleAnimationEnd);
    });
  }

  <template>
    <div
      class="user-menu-dropdown-wrapper"
      {{didInsert this.setupWrapper}}
      {{closeOnClickOutside
        this.clickOutside
        (hash
          targetSelector=".user-menu-panel"
          secondaryTargetSelector=".user-menu-panel"
        )
      }}
      ...attributes
    >
      <UserMenu @closeUserMenu={{fn @toggleUserMenu false}} />
    </div>
  </template>
}
