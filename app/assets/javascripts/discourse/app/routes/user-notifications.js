import ViewingActionType from "discourse/mixins/viewing-action-type";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend(ViewingActionType, {
  appEvents: service(),
  currentUser: service(),
  siteSettings: service(),
  site: service(),
  controllerName: "user-notifications",
  queryParams: { filter: { refreshModel: true } },

  async model(params) {
    const username = this.modelFor("user").get("username");

    if (
      this.currentUser.username === username ||
      this.currentUser.admin
    ) {
      let notifications = await this.store.find("notification", {
        username,
        filter: params.filter,
      });

      const items =  notifications.map((n) => {
        const props = {
          appEvents: this.appEvents,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          site: this.site,
          notification: n,
        };
        return new UserMenuNotificationItem(props)
      });

      console.log(notifications.loadMore)
      return {
        items,
        loadMore: notifications.loadMore,
      };
    }
  },

  setupController(controller) {
    this._super(...arguments);
    controller.set("user", this.modelFor("user"));
    this.viewingActionType(-1);
  },

  titleToken() {
    return I18n.t("user.notifications");
  },
});
