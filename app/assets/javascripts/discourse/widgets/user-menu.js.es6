import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { formatUsername } from "discourse/lib/utilities";
import hbs from "discourse/widgets/hbs-compiler";

const UserMenuAction = {
  QUICK_ACCESS: "quickAccess"
};

const QuickAccess = {
  BOOKMARKS: "bookmarks",
  MESSAGES: "messages",
  NOTIFICATIONS: "notifications",
  PROFILE: "profile"
};

let extraGlyphs;

export function addUserMenuGlyph(glyph) {
  extraGlyphs = extraGlyphs || [];
  extraGlyphs.push(glyph);
}

createWidget("user-menu-links", {
  tagName: "div.menu-links-header",

  profileLink() {
    const link = {
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.PROFILE,
      route: "user",
      model: this.currentUser,
      className: "user-activity-link",
      icon: "user",
      rawLabel: formatUsername(this.currentUser.username)
    };

    if (this.currentUser.is_anonymous) {
      link.label = "user.profile";
      link.rawLabel = null;
    }

    return link;
  },

  notificationsGlyph() {
    return {
      label: "user.notifications",
      className: "user-notifications-link",
      icon: "bell",
      href: `${this.attrs.path}/notifications`,
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.NOTIFICATIONS
    };
  },

  bookmarksGlyph() {
    return {
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.BOOKMARKS,
      label: "user.bookmarks",
      className: "user-bookmarks-link",
      icon: "bookmark",
      href: `${this.attrs.path}/activity/bookmarks`
    };
  },

  messagesGlyph() {
    return {
      action: UserMenuAction.QUICK_ACCESS,
      actionParam: QuickAccess.MESSAGES,
      label: "user.private_messages",
      className: "user-pms-link",
      icon: "envelope",
      href: `${this.attrs.path}/messages`
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
    const links = [this.profileLink()];
    const glyphs = [];

    if (extraGlyphs) {
      extraGlyphs.forEach(g => {
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

    if (this.siteSettings.enable_personal_messages) {
      glyphs.push(this.messagesGlyph());
    }

    return h("ul.menu-links-row", [
      links.map(l => h("li.user", this.linkHtml(l))),
      h("li.glyphs", glyphs.map(l => this.glyphHtml(l)))
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
  }
});

createWidget("user-menu-dismiss-link", {
  tagName: "div.dismiss-link",

  template: hbs`
    <ul class='menu-links'>
      <li>
        {{link action="dismissNotifications"
          className="dismiss"
          tabindex="0"
          icon="check"
          label="user.dismiss"
          title="user.dismiss_notifications_tooltip"}}
      </li>
    </ul>
  `
});

export default createWidget("user-menu", {
  tagName: "div.user-menu",
  buildKey: () => "user-menu",

  settings: {
    maxWidth: 320,
    showLogoutButton: true
  },

  defaultState() {
    return {
      currentQuickAccess: QuickAccess.NOTIFICATIONS,
      hasUnread: false,
      markUnread: null
    };
  },

  panelContents() {
    const path = this.currentUser.get("path");
    const { currentQuickAccess } = this.state;

    const result = [
      this.attach("user-menu-links", {
        path,
        currentQuickAccess
      }),
      this.quickAccessPanel(path)
    ];

    if (this.state.hasUnread) {
      result.push(h("hr.bottom-area"));
      result.push(this.attach("user-menu-dismiss-link"));
    }

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
      contents: () => this.panelContents()
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
      const windowWidth = parseInt($window.width(), 10);
      const $panel = $(".menu-panel");
      $panel.addClass("animate");
      $panel.css("right", -windowWidth);
      const $headerCloak = $(".header-cloak");
      $headerCloak.addClass("animate");
      $headerCloak.css("opacity", 0);
      Ember.run.later(() => this.sendWidgetAction("toggleUserMenu"), 200);
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
      showLogoutButton
    });
  }
});
