import Component from "@ember/component";
import { bind } from "discourse-common/utils/decorators";
import { scrollTop } from "discourse/mixins/scroll-top";

export default Component.extend({
  tagName: "",

  didInsertElement() {
    this._super(...arguments);

    const navItems = [
      this.showNotificationsTab,
      this.showPrivateMessages,
      this.canInviteToForum,
      this.showBadges,
      this.model.can_edit,
    ];

    document.documentElement.style.setProperty(
      "--user-nav-count",
      navItems.filter(Boolean).length + 2 // 2 always shown
    );
  },

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
  },

  @bind
  collapseMobileProfileMenu(event) {
    let shouldcollapseProfileMenu = false;

    const allowedInsideClick = event.composedPath().some((element) => {
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
  },

  actions: {
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
    },
  },
});
