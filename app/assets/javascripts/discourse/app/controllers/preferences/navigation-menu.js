import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class extends Controller {
  @tracked saved = false;

  subpageTitle = i18n("user.preferences_nav.navigation_menu");

  saveAttrNames = [
    "sidebar_link_to_filtered_list",
    "sidebar_show_count_of_new_items",
  ];

  @action
  save() {
    const initialSidebarLinkToFilteredList =
      this.model.sidebarLinkToFilteredList;
    const initialSidebarShowCountOfNewItems =
      this.model.sidebarShowCountOfNewItems;

    this.model.set(
      "user_option.sidebar_link_to_filtered_list",
      this.newSidebarLinkToFilteredList
    );
    this.model.set(
      "user_option.sidebar_show_count_of_new_items",
      this.newSidebarShowCountOfNewItems
    );

    this.model
      .save(this.saveAttrNames)
      .then(() => {
        this.saved = true;
      })
      .catch((error) => {
        this.model.set(
          "user_option.sidebar_link_to_filtered_list",
          initialSidebarLinkToFilteredList
        );
        this.model.set(
          "user_option.sidebar_show_count_of_new_items",
          initialSidebarShowCountOfNewItems
        );

        popupAjaxError(error);
      });
  }
}
