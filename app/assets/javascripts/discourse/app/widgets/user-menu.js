import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { later } from "@ember/runloop";

const UserMenuAction = {
  QUICK_ACCESS: "quickAccess",
};

const QuickAccess = {
  BOOKMARKS: "bookmarks",
  MESSAGES: "messages",
  NOTIFICATIONS: "notifications",
  PROFILE: "profile",
};

let extraGlyphs;

export function addUserMenuGlyph(glyph) {
  extraGlyphs = extraGlyphs || [];
  extraGlyphs.push(glyph);
}

createWidget("user-menu-links", {
  tagName: "div.menu-links-header",

  profileGlyph() {
    return {
      label: "user.preferences",
      className: "user-preferences-link",
      icon: "user",
      href: `${this.attrs.path}/summary`,
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.PROFILE,
      alt: "user.preferences",
    };
  },

  notificationsGlyph() {
    return {
      label: "user.notifications",
      className: "user-notifications-link",
      icon: "bell",
      href: `${this.attrs.path}/notifications`,
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.NOTIFICATIONS,
      alt: "user.notifications",
    };
  },

  bookmarksGlyph() {
    return {
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.BOOKMARKS,
      label: "user.bookmarks",
      className: "user-bookmarks-link",
      icon: "bookmark",
      href: `${this.attrs.path}/activity/bookmarks`,
      alt: "user.bookmarks",
    };
  },

  messagesGlyph() {
    return {
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.MESSAGES,
      label: "user.private_messages",
      className: "user-pms-link",
      icon: "envelope",
      href: `${this.attrs.path}/messages`,
      alt: "user.private_messages",
    };
  },

  linkHtml(link) {
    if (this.isActive(link)) {
      link = this.markAsActive(link);
    }
    return this.attach("link", link);
  },

  glyphHtml(glyph) {
    if (this.isActive(glyph)) {
      glyph = this.markAsActive(glyph);
    }
    return this.attach("link", $.extend(glyph, { hideLabel: true }));
  },

  html() {
    const glyphs = [];

    if (extraGlyphs) {
      extraGlyphs.forEach((g) => {
        if (typeof g === "function") {
          g = g(this);
        }
        if (g) {
          glyphs.push(g);
        }
      });
    }

    glyphs.push(this.notificationsGlyph());
    glyphs.push(this.bookmarksGlyph());

    if (this.siteSettings.enable_personal_messages || this.currentUser.staff) {
      glyphs.push(this.messagesGlyph());
    }

    glyphs.push(this.profileGlyph());

    return h("ul.menu-links-row", [
      h(
        "li.glyphs",
        glyphs.map((l) => this.glyphHtml(l))
      ),
    ]);
  },

  markAsActive(definition) {
    // Clicking on an active quick access tab icon should redirect the user to
    // the full page.
    definition.action = null;
    definition.actionParam = null;

    if (definition.className) {
      definition.className += " active";
    } else {
      definition.className = "active";
    }

    return definition;
  },

  isActive({ action, actionParam }) {
    return (
      action === UserMenuAction.QUICK_ACCESS &&
      actionParam === this.attrs.currentQuickAccess
    );
  },
});

export default createWidget("user-menu", {
  tagName: "div.user-menu",
  buildKey: () => "user-menu",

  settings: {
    maxWidth: 320,
    showLogoutButton: true,
  },

  defaultState() {
    return {
      currentQuickAccess: QuickAccess.NOTIFICATIONS,
      hasUnread: false,
      markUnread: null,
    };
  },

  panelContents() {
    const path = this.currentUser.get("path");
    const { currentQuickAccess } = this.state;

    const result = [
      this.attach("user-menu-links", {
        path,
        currentQuickAccess,
      }),
      this.quickAccessPanel(path),
    ];

    return result;
  },

  dismissNotifications() {
    return this.state.markRead();
  },

  itemsLoaded({ hasUnread, markRead }) {
    this.state.hasUnread = hasUnread;
    this.state.markRead = markRead;
  },

  html() {
    return this.attach("menu-panel", {
      maxWidth: this.settings.maxWidth,
      contents: () => this.panelContents(),
    });
  },

  clickOutsideMobile(e) {
    const $centeredElement = $(document.elementFromPoint(e.clientX, e.clientY));
    if (
      $centeredElement.parents(".panel").length &&
      !$centeredElement.hasClass("header-cloak")
    ) {
      this.sendWidgetAction("toggleUserMenu");
    } else {
      const $window = $(window);
      const windowWidth = $window.width();
      const $panel = $(".menu-panel");
      $panel.addClass("animate");
      $panel.css("right", -windowWidth);
      const $headerCloak = $(".header-cloak");
      $headerCloak.addClass("animate");
      $headerCloak.css("opacity", 0);
      later(() => this.sendWidgetAction("toggleUserMenu"), 200);
    }
  },

  clickOutside(e) {
    if (this.site.mobileView) {
      this.clickOutsideMobile(e);
    } else {
      this.sendWidgetAction("toggleUserMenu");
    }
  },

  quickAccess(type) {
    if (this.state.currentQuickAccess !== type) {
      this.state.currentQuickAccess = type;
    }
  },

  quickAccessPanel(path) {
    const { showLogoutButton } = this.settings;
    // This deliberately does NOT fallback to a default quick access panel.
    return this.attach(`quick-access-${this.state.currentQuickAccess}`, {
      path,
      showLogoutButton,
    });
  },
});
