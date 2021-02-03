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

  _tabAttrs(quickAccessType) {
    return {
      "aria-controls": `quick-access-${quickAccessType}`,
      "aria-selected": "false",
      tabindex: "-1",
    };
  },

  // TODO: Remove when 2.7 gets released.
  _structureAsTab(extraGlyph) {
    const glyph = extraGlyph;
    // Assume glyph is a button if it has a data-url field.
    if (!glyph.data || !glyph.data.url) {
      glyph.title = glyph.label;
      glyph.data = { url: glyph.href };

      glyph.label = null;
      glyph.href = null;
    }

    glyph.role = "tab";
    glyph.tabAttrs = this._tabAttrs(glyph.actionParam);

    return glyph;
  },

  profileGlyph() {
    return {
      title: "user.preferences",
      className: "user-preferences-link",
      icon: "user",
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.PROFILE,
      data: { url: `${this.attrs.path}/summary` },
      role: "tab",
      tabAttrs: this._tabAttrs(QuickAccess.PROFILE),
    };
  },

  notificationsGlyph() {
    return {
      title: "user.notifications",
      className: "user-notifications-link",
      icon: "bell",
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.NOTIFICATIONS,
      data: { url: `${this.attrs.path}/notifications` },
      role: "tab",
      tabAttrs: this._tabAttrs(QuickAccess.NOTIFICATIONS),
    };
  },

  bookmarksGlyph() {
    return {
      title: "user.bookmarks",
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.BOOKMARKS,
      className: "user-bookmarks-link",
      icon: "bookmark",
      data: { url: `${this.attrs.path}/activity/bookmarks` },
      "aria-label": "user.bookmarks",
      role: "tab",
      tabAttrs: this._tabAttrs(QuickAccess.BOOKMARKS),
    };
  },

  messagesGlyph() {
    return {
      title: "user.private_messages",
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.MESSAGES,
      className: "user-pms-link",
      icon: "envelope",
      data: { url: `${this.attrs.path}/messages` },
      role: "tab",
      tabAttrs: this._tabAttrs(QuickAccess.MESSAGES),
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
    return this.attach("flat-button", glyph);
  },

  html() {
    const glyphs = [];

    if (extraGlyphs) {
      extraGlyphs.forEach((g) => {
        if (typeof g === "function") {
          g = g(this);
        }
        if (g) {
          const structuredGlyph = this._structureAsTab(g);
          glyphs.push(structuredGlyph);
        }
      });
    }

    glyphs.push(this.notificationsGlyph());
    glyphs.push(this.bookmarksGlyph());

    if (this.siteSettings.enable_personal_messages || this.currentUser.staff) {
      glyphs.push(this.messagesGlyph());
    }

    glyphs.push(this.profileGlyph());

    return h("div.menu-links-row", [
      h(
        "div.glyphs",
        { attributes: { "aria-label": "Menu links", role: "tablist" } },
        glyphs.map((l) => this.glyphHtml(l))
      ),
    ]);
  },

  markAsActive(definition) {
    // Clicking on an active quick access tab icon should redirect the user to
    // the full page.
    definition.action = null;
    definition.actionParam = null;
    definition.url = definition.data.url;

    if (definition.className) {
      definition.className += " active";
    } else {
      definition.className = "active";
    }

    definition.tabAttrs["tabindex"] = "0";
    definition.tabAttrs["aria-selected"] = "true";

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
