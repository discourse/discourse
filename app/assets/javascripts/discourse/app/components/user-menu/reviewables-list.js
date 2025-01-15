import { service } from "@ember/service";
import UserMenuItemsList from "discourse/components/user-menu/items-list";
import { ajax } from "discourse/lib/ajax";
import getUrl from "discourse/lib/get-url";
import UserMenuReviewableItem from "discourse/lib/user-menu/reviewable-item";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import { i18n } from "discourse-i18n";

export default class UserMenuReviewablesList extends UserMenuItemsList {
  @service currentUser;
  @service siteSettings;
  @service site;

  get showAllHref() {
    return getUrl("/review");
  }

  get showAllTitle() {
    return i18n("user_menu.reviewable.view_all");
  }

  get itemsCacheKey() {
    return "pending-reviewables";
  }

  fetchItems() {
    return ajax("/review/user-menu-list").then((data) => {
      this.currentUser.updateReviewableCount(data.reviewable_count);

      return data.reviewables.map((item) => {
        return new UserMenuReviewableItem({
          reviewable: UserMenuReviewable.create(item),
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          site: this.site,
        });
      });
    });
  }
}
