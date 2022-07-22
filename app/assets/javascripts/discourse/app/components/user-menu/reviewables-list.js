import UserMenuItemsList from "discourse/components/user-menu/items-list";
import { ajax } from "discourse/lib/ajax";
import { MiniReviewable } from "discourse/models/reviewable";
import I18n from "I18n";
import getUrl from "discourse-common/lib/get-url";

export default class UserMenuReviewablesList extends UserMenuItemsList {
  get showAll() {
    return true;
  }

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
    return ajax("/review/lightweight-list").then((data) => {
      return data.reviewables.map((item) => {
        return MiniReviewable.create(item);
      });
    });
  }
}
