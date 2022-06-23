import I18n from "I18n";
import { Promise } from "rsvp";
import QuickAccessItem from "discourse/widgets/quick-access-item";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { createWidgetFrom } from "discourse/widgets/widget";
import showModal from "discourse/lib/show-modal";

const _extraItems = [];

export function addQuickAccessProfileItem(item) {
  _extraItems.push(item);
}

createWidgetFrom(QuickAccessItem, "logout-item", {
  tagName: "li.logout",

  html() {
    return this.attach("flat-button", {
      action: "logout",
      icon: "sign-out-alt",
      label: "user.log_out",
    });
  },
});

createWidgetFrom(QuickAccessItem, "user-status-item", {
  tagName: "li.user-status",

  html() {
    const action = "hideMenuAndSetStatus";
    const userStatus = this.currentUser.status;
    if (userStatus) {
      return this.attach("flat-button", {
        action,
        emoji: userStatus.emoji,
        translatedLabel: userStatus.description,
      });
    } else {
      return this.attach("flat-button", {
        action,
        icon: "plus-circle",
        label: "user_status.set_custom_status",
      });
    }
  },

  hideMenuAndSetStatus() {
    this.sendWidgetAction("toggleUserMenu");
    showModal("user-status", {
      title: "user_status.set_custom_status",
      modalClass: "user-status",
    });
  },
});

createWidgetFrom(QuickAccessPanel, "quick-access-profile", {
  tagName: "div.quick-access-panel.quick-access-profile",

  buildKey: () => "quick-access-profile",

  hideBottomItems() {
    // Never show the button to the full profile page.
    return true;
  },

  findNewItems() {
    return Promise.resolve(this._getItems());
  },

  itemHtml(item) {
    const widgetType = item.widget || "quick-access-item";
    return this.attach(widgetType, item);
  },

  _getItems() {
    const items = [];

    if (this.siteSettings.enable_user_status) {
      items.push({ widget: "user-status-item" });
    }
    items.push(...this._getDefaultItems());
    if (this._showToggleAnonymousButton()) {
      items.push(this._toggleAnonymousButton());
    }
    items.push(..._extraItems);

    if (this.attrs.showLogoutButton) {
      items.push({ widget: "logout-item" });
    }
    return items;
  },

  _getDefaultItems() {
    let defaultItems = [
      {
        icon: "user",
        href: `${this.attrs.path}/summary`,
        content: I18n.t("user.summary.title"),
        className: "summary",
      },
      {
        icon: "stream",
        href: `${this.attrs.path}/activity`,
        content: I18n.t("user.activity_stream"),
        className: "activity",
      },
    ];

    if (this.currentUser.can_invite_to_forum) {
      defaultItems.push({
        icon: "user-plus",
        href: `${this.attrs.path}/invited`,
        content: I18n.t("user.invited.title"),
        className: "invites",
      });
    }

    defaultItems.push(
      {
        icon: "pencil-alt",
        href: `${this.attrs.path}/activity/drafts`,
        content:
          this.currentUser.draft_count > 0
            ? I18n.t("drafts.label_with_count", {
                count: this.currentUser.draft_count,
              })
            : I18n.t("drafts.label"),
        className: "drafts",
      },
      {
        icon: "cog",
        href: `${this.attrs.path}/preferences`,
        content: I18n.t("user.preferences"),
        className: "preferences",
      }
    );
    defaultItems.push({ widget: "do-not-disturb" });

    return defaultItems;
  },

  _toggleAnonymousButton() {
    if (this.currentUser.is_anonymous) {
      return {
        action: "toggleAnonymous",
        className: "disable-anonymous",
        content: I18n.t("switch_from_anon"),
        icon: "ban",
      };
    } else {
      return {
        action: "toggleAnonymous",
        className: "enable-anonymous",
        content: I18n.t("switch_to_anon"),
        icon: "user-secret",
      };
    }
  },

  _showToggleAnonymousButton() {
    return (
      (this.siteSettings.allow_anonymous_posting &&
        this.currentUser.trust_level >=
          this.siteSettings.anonymous_posting_min_trust_level) ||
      this.currentUser.is_anonymous
    );
  },
});
