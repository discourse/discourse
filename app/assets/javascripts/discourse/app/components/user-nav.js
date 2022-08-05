import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
import { scrollTop } from "discourse/mixins/scroll-top";
import { action } from "@ember/object";

export default class UserNav extends GlimmerComponent {
  @bind
  userMenuOutside(e) {
    const isClickOnParent = e.composedPath().some((element) => {
      if (element?.classList?.contains("user-primary-navigation_item-parent")) {
        return true;
      }
    });

    if (!isClickOnParent) {
      document.querySelectorAll(".user-nav > li").forEach((navParent) => {
        navParent.classList.remove("show-children");
      });

      document.removeEventListener("click", this.userMenuOutside);
    }
  }

  @bind
  collapseMobileProfileMenu(e) {
    let shouldcollapseProfileMenu = false;

    const allowedInsideClick = e.composedPath().some((element) => {
      if (
        element.classList?.contains("user-primary-navigation_submenu-link") ||
        (!element.classList?.contains("user-primary-navigation_item-parent") &&
          element.nodeName?.includes("LI"))
      ) {
        shouldcollapseProfileMenu = true;
        return false;
      }

      if (element.classList?.contains("user-primary-navigation_item-parent")) {
        return true;
      }
    });

    if (shouldcollapseProfileMenu || !allowedInsideClick) {
      scrollTop();
      this.set("showMobileUserMenu", false);
      document.removeEventListener("click", this.collapseMobileProfileMenu);
    }
  }

  @action
  toggleSubmenu(e) {
    document.addEventListener("click", this.userMenuOutside);

    if (e.currentTarget.classList.contains("show-children")) {
      return e.currentTarget.classList.remove("show-children");
    }

    document.querySelectorAll(".user-nav > li").forEach((navParent) => {
      navParent.classList.remove("show-children");
    });

    e.currentTarget.classList.toggle("show-children");

    if (this.site.mobileView) {
      // scroll to end so the last submenu is visible
      document
        .querySelector(".preferences-nav")
        .scrollIntoView({ inline: "end" });
    }
  }
}
