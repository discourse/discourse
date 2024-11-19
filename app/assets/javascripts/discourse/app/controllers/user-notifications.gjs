import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DismissNotificationConfirmationModal from "discourse/components/modal/dismiss-notification-confirmation";
import RelativeDate from "discourse/components/relative-date";
import { ajax } from "discourse/lib/ajax";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const _beforeLoadMoreCallbacks = [];
export function addBeforeLoadMoreCallback(fn) {
  _beforeLoadMoreCallbacks.push(fn);
}

export default class UserNotificationsController extends Controller {
  @service modal;
  @service appEvents;
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked filter = "all";

  queryParams = ["filter"];

  get listContainerClassNames() {
    return `user-notifications-list ${
      this.siteSettings.show_user_menu_avatars ? "show-avatars" : ""
    }`;
  }

  @discourseComputed("filter")
  isFiltered() {
    return this.filter && this.filter !== "all";
  }

  @discourseComputed("model.content.@each")
  items() {
    return this.model.map((notification) => {
      const props = {
        appEvents: this.appEvents,
        currentUser: this.currentUser,
        siteSettings: this.siteSettings,
        site: this.site,
        notification,
        endComponent: <template>
          <RelativeDate @date={{notification.created_at}} />
        </template>,
      };
      return new UserMenuNotificationItem(props);
    });
  }

  @discourseComputed("model.content.@each.read")
  allNotificationsRead() {
    return !this.get("model.content").some(
      (notification) => !notification.get("read")
    );
  }

  @discourseComputed("isFiltered", "model.content.length", "loading")
  doesNotHaveNotifications(isFiltered, contentLength, loading) {
    return !loading && !isFiltered && contentLength === 0;
  }

  @discourseComputed("isFiltered", "model.content.length")
  nothingFound(isFiltered, contentLength) {
    return isFiltered && contentLength === 0;
  }

  @discourseComputed()
  emptyStateBody() {
    return htmlSafe(
      i18n("user.no_notifications_page_body", {
        preferencesUrl: getURL("/my/preferences/notifications"),
        icon: iconHTML("bell"),
      })
    );
  }

  async markRead() {
    await ajax("/notifications/mark-read", { type: "PUT" });
    this.model.forEach((notification) => notification.set("read", true));
  }

  @action
  updateFilter(value) {
    this.loading = true;
    this.filter = value;
  }

  @action
  async resetNew() {
    if (this.currentUser.unread_high_priority_notifications > 0) {
      this.modal.show(DismissNotificationConfirmationModal, {
        model: {
          confirmationMessage: i18n(
            "notifications.dismiss_confirmation.body.default",
            {
              count: this.currentUser.unread_high_priority_notifications,
            }
          ),
          dismissNotifications: () => this.markRead(),
        },
      });
    } else {
      this.markRead();
    }
  }

  @action
  loadMore() {
    if (
      _beforeLoadMoreCallbacks.length &&
      !_beforeLoadMoreCallbacks.some((fn) => fn(this))
    ) {
      // Return early if any callbacks return false, short-circuiting the default loading more logic
      return;
    }

    this.model.loadMore();
  }
}
