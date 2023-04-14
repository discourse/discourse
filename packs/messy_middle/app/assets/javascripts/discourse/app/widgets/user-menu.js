import discourseLater from "discourse-common/lib/later";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";

const UserMenuAction = {
  QUICK_ACCESS: "quickAccess",
};

const QuickAccess = {
  BOOKMARKS: "bookmarks",
  MESSAGES: "messages",
  NOTIFICATIONS: "notifications",
  PROFILE: "profile",
};

const Titles = {
  bookmarks: "user.bookmarks",
  messages: "user.private_messages",
  notifications: "user.notifications",
  profile: "user.preferences",
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

    if (glyph.className) {
      glyph.className += " menu-link";
    } else {
      glyph.className = "menu-link";
    }

    glyph.role = "tab";
    glyph.tabAttrs = this._tabAttrs(glyph.actionParam);

    return glyph;
  },

  profileGlyph() {
    return {
      title: Titles["profile"],
      className: "user-preferences-link menu-link",
      id: QuickAccess.PROFILE,
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
      title: Titles["notifications"],
      className: "user-notifications-link menu-link",
      id: QuickAccess.NOTIFICATIONS,
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
      title: Titles["bookmarks"],
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.BOOKMARKS,
      className: "user-bookmarks-link menu-link",
      id: QuickAccess.BOOKMARKS,
      icon: "bookmark",
      data: { url: `${this.attrs.path}/activity/bookmarks` },
      "aria-label": "user.bookmarks",
      role: "tab",
      tabAttrs: this._tabAttrs(QuickAccess.BOOKMARKS),
    };
  },

  messagesGlyph() {
    return {
      title: Titles["messages"],
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.MESSAGES,
      className: "user-pms-link menu-link",
      id: QuickAccess.MESSAGES,
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

  glyphHtml(glyph, idx) {
    if (this.isActive(glyph)) {
      glyph = this.markAsActive(glyph);
    }
    glyph.data["tab-number"] = `${idx}`;

    return this.attach("flat-button", glyph);
  },

  html() {
    const glyphs = [this.notificationsGlyph()];

    if (extraGlyphs) {
      extraGlyphs.forEach((g) => {
        if (typeof g === "function") {
          g = g(this);
        }
        if (g) {
          const structuredGlyph = this._structureAsTab(g);
          Titles[structuredGlyph.actionParam] =
            structuredGlyph.title || structuredGlyph.label;
          glyphs.push(structuredGlyph);
        }
      });
    }

    glyphs.push(this.bookmarksGlyph());

    if (this.currentUser?.can_send_private_messages) {
      glyphs.push(this.messagesGlyph());
    }

    glyphs.push(this.profileGlyph());

    return h("div.menu-links-row", [
      h(
        "div.glyphs",
        { attributes: { "aria-label": "Menu links", role: "tablist" } },
        glyphs.map((l, index) => this.glyphHtml(l, index))
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

  userMenuNavigation(nav) {
    const maxTabNumber = document.querySelectorAll(".glyphs button").length - 1;
    const isLeft = nav.key === "ArrowLeft";

    let nextTab = isLeft ? nav.tabNumber - 1 : nav.tabNumber + 1;

    if (isLeft && nextTab < 0) {
      nextTab = maxTabNumber;
    }

    if (!isLeft && nextTab > maxTabNumber) {
      nextTab = 0;
    }

    document
      .querySelector(`.menu-link[role='tab'][data-tab-number='${nextTab}']`)
      .focus();
  },

  defaultState() {
    return {
      currentQuickAccess: QuickAccess.NOTIFICATIONS,
      titleKey: Titles["notifications"],
      hasUnread: false,
      markUnread: null,
    };
  },

  panelContents() {
    const path = this.currentUser.get("path");
    const { currentQuickAccess, titleKey } = this.state;

    const result = [
      this.attach("user-menu-links", {
        path,
        currentQuickAccess,
      }),
      this.quickAccessPanel(path, titleKey, currentQuickAccess),
    ];

    return result;
  },

  dismissNotifications() {
    const unreadHighPriorityNotifications = this.currentUser.get(
      "unread_high_priority_notifications"
    );

    if (unreadHighPriorityNotifications > 0) {
      return showModal("dismiss-notification-confirmation").setProperties({
        confirmationMessage: I18n.t(
          "notifications.dismiss_confirmation.body.default",
          {
            count: unreadHighPriorityNotifications,
          }
        ),
        dismissNotifications: () => this.state.markRead(),
      });
    } else {
      return this.state.markRead();
    }
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
    const centeredElement = document.elementFromPoint(e.clientX, e.clientY);
    const parents = document
      .elementsFromPoint(e.clientX, e.clientY)
      .some((ele) => ele.classList.contains("panel"));
    if (!centeredElement.classList.contains("header-cloak") && parents) {
      this.sendWidgetAction("toggleUserMenu");
    } else {
      const windowWidth = document.body.offsetWidth;
      const panel = document.querySelector(".menu-panel");
      panel.classList.add("animate");
      let offsetDirection =
        document.querySelector("html").classList["direction"] === "rtl"
          ? -1
          : 1;
      panel.style.setProperty("--offset", `${offsetDirection * windowWidth}px`);
      const headerCloak = document.querySelector(".header-cloak");
      headerCloak.classList.add("animate");
      headerCloak.style.setProperty("--opacity", 0);
      discourseLater(() => this.sendWidgetAction("toggleUserMenu"), 200);
    }
  },

  clickOutside(e) {
    if (this.site.mobileView) {
      this.clickOutsideMobile(e);
    } else {
      this.sendWidgetAction("toggleUserMenu");
    }
  },

  keyDown(e) {
    if (e.key === "Escape") {
      this.sendWidgetAction("toggleUserMenu");
      e.preventDefault();
      return false;
    }
  },

  quickAccess(type) {
    if (this.state.currentQuickAccess !== type) {
      this.state.currentQuickAccess = type;
      this.state.titleKey = Titles[type];
    }
  },

  quickAccessPanel(path, titleKey, currentQuickAccess) {
    const { showLogoutButton } = this.settings;
    // This deliberately does NOT fallback to a default quick access panel.
    return this.attach(`quick-access-${this.state.currentQuickAccess}`, {
      path,
      showLogoutButton,
      titleKey,
      currentQuickAccess,
    });
  },
});
