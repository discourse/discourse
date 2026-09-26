import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "discourse/lib/service";
import { trustHTML } from "@ember/template";
import curryComponent from "ember-curry-component";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import { beforeLoadMoreCallbacks } from "discourse/lib/plugin-registries/notifications";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import { i18n } from "discourse-i18n";
import ModalService from "discourse/services/modal";
import AppEventsService from "discourse/services/app-events";
import CurrentUserService from "discourse/services/current-user";
import SiteService from "discourse/services/site";
import SiteSettingsService from "discourse/services/site-settings";

export { addBeforeLoadMoreCallback } from "discourse/lib/plugin-registries/notifications";

export default class UserNotificationsController extends Controller {
  @service(() => ModalService) modal;
  @service(() => AppEventsService) appEvents;
  @service(() => CurrentUserService) currentUser;
  @service(() => SiteService) site;
  @service(() => SiteSettingsService) siteSettings;

  @tracked filter = "all";

  queryParams = ["filter"];

  get isFiltered() {
    return this.filter && this.filter !== "all";
  }

  get items() {
    return this.model.content.map((notification) => {
      const props = {
        appEvents: this.appEvents,
        currentUser: this.currentUser,
        siteSettings: this.siteSettings,
        site: this.site,
        notification,
        endComponent: curryComponent(
          DRelativeDate,
          { date: notification.created_at },
          getOwner(this)
        ),
      };
      return new UserMenuNotificationItem(props);
    });
  }

  get allNotificationsRead() {
    return !this.model.content.some(
      (notification) => !notification.get("read")
    );
  }

  get doesNotHaveNotifications() {
    return (
      !this.model.loading && !this.isFiltered && this.model.content.length === 0
    );
  }

  get nothingFound() {
    return this.isFiltered && this.model.content.length === 0;
  }

  get emptyStateBody() {
    return trustHTML(
      i18n("user.no_notifications_page_body", {
        preferencesUrl: getURL("/my/preferences/notifications"),
        icon: iconHTML("bell"),
      })
    );
  }

  async markRead() {
    await ajax("/notifications/mark-read", { type: "PUT" });
    this.model.content.forEach((notification) =>
      notification.set("read", true)
    );
  }

  @action
  updateFilter(value) {
    this.filter = value;
  }

  @action
  async resetNew() {
    if (this.currentUser.unread_high_priority_notifications > 0) {
      this.modal.show(
        () =>
          import("discourse/components/modal/dismiss-notification-confirmation"),
        {
          model: {
            confirmationMessage: i18n(
              "notifications.dismiss_confirmation.body.default",
              {
                count: this.currentUser.unread_high_priority_notifications,
              }
            ),
            dismissNotifications: () => this.markRead(),
          },
        }
      );
    } else {
      this.markRead();
    }
  }

  @action
  loadMore() {
    if (
      beforeLoadMoreCallbacks.length &&
      !beforeLoadMoreCallbacks.some((fn) => fn(this))
    ) {
      // Return early if any callbacks return false, short-circuiting the default loading more logic
      return;
    }

    this.model.loadMore();
  }
}
