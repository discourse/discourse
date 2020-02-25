import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { createWidgetFrom } from "discourse/widgets/widget";
import { Promise } from "rsvp";

createWidgetFrom(QuickAccessPanel, "quick-access-profile", {
  buildKey: () => "quick-access-profile",

  hasMore() {
    // Never show the button to the full profile page.
    return false;
  },

  findNewItems() {
    return Promise.resolve(this._getItems());
  },

  itemHtml(item) {
    return this.attach("quick-access-item", item);
  },

  _getItems() {
    const items = this._getDefaultItems();
    if (this._showToggleAnonymousButton()) {
      items.push(this._toggleAnonymousButton());
    }
    if (this.attrs.showLogoutButton) {
      items.push(this._logOutButton());
    }
    return items;
  },

  _getDefaultItems() {
    let defaultItems = [
      {
        icon: "user",
        href: `${this.attrs.path}/summary`,
        content: I18n.t("user.summary.title")
      },
      {
        icon: "stream",
        href: `${this.attrs.path}/activity`,
        content: I18n.t("user.activity_stream")
      }
    ];
    if (this.siteSettings.enable_personal_messages) {
      defaultItems.push({
        icon: "envelope",
        href: `${this.attrs.path}/messages`,
        content: I18n.t("user.private_messages")
      });
    }
    defaultItems.push(
      {
        icon: "pencil-alt",
        href: `${this.attrs.path}/activity/drafts`,
        content: I18n.t("user_action_groups.15")
      },
      {
        icon: "cog",
        href: `${this.attrs.path}/preferences`,
        content: I18n.t("user.preferences")
      }
    );
    return defaultItems;
  },

  _toggleAnonymousButton() {
    if (this.currentUser.is_anonymous) {
      return {
        action: "toggleAnonymous",
        className: "disable-anonymous",
        content: I18n.t("switch_from_anon"),
        icon: "ban"
      };
    } else {
      return {
        action: "toggleAnonymous",
        className: "enable-anonymous",
        content: I18n.t("switch_to_anon"),
        icon: "user-secret"
      };
    }
  },

  _logOutButton() {
    return {
      action: "logout",
      className: "logout",
      content: I18n.t("user.log_out"),
      icon: "sign-out-alt"
    };
  },

  _showToggleAnonymousButton() {
    return (
      (this.siteSettings.allow_anonymous_posting &&
        this.currentUser.trust_level >=
          this.siteSettings.anonymous_posting_min_trust_level) ||
      this.currentUser.is_anonymous
    );
  }
});
