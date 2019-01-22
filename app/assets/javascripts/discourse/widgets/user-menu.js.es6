import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { formatUsername } from "discourse/lib/utilities";
import hbs from "discourse/widgets/hbs-compiler";

let extraGlyphs;

export function addUserMenuGlyph(glyph) {
  extraGlyphs = extraGlyphs || [];
  extraGlyphs.push(glyph);
}

createWidget("user-menu-links", {
  tagName: "div.menu-links-header",

  html(attrs) {
    const { currentUser, siteSettings } = this;

    const isAnon = currentUser.is_anonymous;
    const allowAnon =
      (siteSettings.allow_anonymous_posting &&
        currentUser.trust_level >=
          siteSettings.anonymous_posting_min_trust_level) ||
      isAnon;

    const path = attrs.path;
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

    glyphs.push({
      label: "user.bookmarks",
      className: "user-bookmarks-link",
      icon: "bookmark",
      href: `${path}/activity/bookmarks`
    });

    if (siteSettings.enable_personal_messages) {
      glyphs.push({
        label: "user.private_messages",
        className: "user-pms-link",
        icon: "envelope",
        href: `${path}/messages`
      });
    }

    const profileLink = {
      route: "user",
      model: currentUser,
      className: "user-activity-link",
      icon: "user",
      rawLabel: formatUsername(currentUser.username)
    };

    if (currentUser.is_anonymous) {
      profileLink.label = "user.profile";
      profileLink.rawLabel = null;
    }

    const links = [profileLink];
    if (allowAnon) {
      if (!isAnon) {
        glyphs.push({
          action: "toggleAnonymous",
          label: "switch_to_anon",
          className: "enable-anonymous",
          icon: "user-secret"
        });
      } else {
        glyphs.push({
          action: "toggleAnonymous",
          label: "switch_from_anon",
          className: "disable-anonymous",
          icon: "ban"
        });
      }
    }

    // preferences always goes last
    glyphs.push({
      label: "user.preferences",
      className: "user-preferences-link",
      icon: "cog",
      href: `${path}/preferences/account`
    });

    return h("ul.menu-links-row", [
      links.map(l => h("li.user", this.attach("link", l))),
      h(
        "li.glyphs",
        glyphs.map(l => this.attach("link", $.extend(l, { hideLabel: true })))
      )
    ]);
  }
});

createWidget("user-menu-dismiss-link", {
  tagName: "div.dismiss-link",

  template: hbs`
    <ul class='menu-links'>
      <li>
        {{attach
          widget="link"
          attrs=(hash
            action="dismissNotifications"
            className="dismiss"
            tabindex="0"
            icon="check"
            label="user.dismiss"
            title="user.dismiss_notifications_tooltip")}}
      </li>
    </ul>
  `
});

export default createWidget("user-menu", {
  tagName: "div.user-menu",
  buildKey: () => "user-menu",

  settings: {
    maxWidth: 300,
    showLogoutButton: true
  },

  defaultState() {
    return {
      hasUnread: false,
      markUnread: null
    };
  },

  panelContents() {
    const path = this.currentUser.get("path");

    let result = [
      this.attach("user-menu-links", { path }),
      this.attach("user-notifications", { path })
    ];

    if (this.settings.showLogoutButton || this.state.hasUnread) {
      result.push(h("hr.bottom-area"));
    }

    if (this.settings.showLogoutButton) {
      result.push(
        h("div.logout-link", [
          h(
            "ul.menu-links",
            h(
              "li",
              this.attach("link", {
                action: "logout",
                className: "logout",
                icon: "sign-out-alt",
                href: "",
                label: "user.log_out"
              })
            )
          )
        ])
      );
    }

    if (this.state.hasUnread) {
      result.push(this.attach("user-menu-dismiss-link"));
    }

    return result;
  },

  dismissNotifications() {
    return this.state.markRead();
  },

  notificationsLoaded({ notifications, markRead }) {
    this.state.hasUnread = notifications.filterBy("read", false).length > 0;
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
  }
});
