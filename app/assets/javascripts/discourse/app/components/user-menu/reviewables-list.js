import UserMenuItemsList from "discourse/components/user-menu/items-list";
import { ajax } from "discourse/lib/ajax";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import I18n from "I18n";
import getUrl from "discourse-common/lib/get-url";

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

  get itemComponent() {
    return "user-menu/reviewable-item";
  }

  fetchItems() {
    return ajax("/review/user-menu-list").then((data) => {
      return data.reviewables.map((item) => {
        return UserMenuReviewable.create(item);
      });
    });
  }
}
