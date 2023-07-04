import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Controller {
  @tracked saved = false;

  subpageTitle = I18n.t("user.preferences_nav.navigation_menu");

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
