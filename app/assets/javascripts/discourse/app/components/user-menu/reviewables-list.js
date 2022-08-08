import UserMenuItemsList from "discourse/components/user-menu/items-list";
import { ajax } from "discourse/lib/ajax";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import I18n from "I18n";
import getUrl from "discourse-common/lib/get-url";
import UserMenuReviewableItem from "discourse/components/user-menu/reviewable-item";

export default class UserMenuReviewablesList extends UserMenuItemsList {
  get showAllHref() {
    return getUrl("/review");
  }

  get showAllTitle() {
    return I18n.t("user_menu.reviewable.view_all");
  }

  get itemsCacheKey() {
    return "pending-reviewables";
  }

  fetchItems() {
    return ajax("/review/user-menu-list").then((data) => {
      return data.reviewables.map((item) => {
        return new UserMenuReviewableItem({
          reviewable: UserMenuReviewable.create(item),
          siteSettings: this.siteSettings,
          site: this.site,
          currentUser: this.currentUser,
        });
      });
    });
  }
}
