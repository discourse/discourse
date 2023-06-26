import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Controller {
  @tracked saved = false;
  @tracked selectedSidebarCategories = [];
  @tracked selectedSidebarTagNames = [];

  subpageTitle = I18n.t("user.preferences_nav.navigation_menu");

  saveAttrNames = [
    "sidebar_category_ids",
    "sidebar_tag_names",
    "sidebar_link_to_filtered_list",
    "sidebar_show_count_of_new_items",
  ];

  @action
  save() {
    const initialSidebarCategoryIds = this.model.sidebarCategoryIds;
    const initialSidebarLinkToFilteredList =
      this.model.sidebarLinkToFilteredList;
    const initialSidebarShowCountOfNewItems =
      this.model.sidebarShowCountOfNewItems;

    this.model.set(
      "sidebarCategoryIds",
      this.selectedSidebarCategories.mapBy("id")
    );

    this.model.set("sidebar_tag_names", this.selectedSidebarTagNames);

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
      .then((result) => {
        if (result.user.sidebar_tags) {
          this.model.set("sidebar_tags", result.user.sidebar_tags);
        }

        this.saved = true;
      })
      .catch((error) => {
        this.model.set("sidebarCategoryIds", initialSidebarCategoryIds);
        this.model.set(
          "user_option.sidebar_link_to_filtered_list",
          initialSidebarLinkToFilteredList
        );
        this.model.set(
          "user_option.sidebar_show_count_of_new_items",
          initialSidebarShowCountOfNewItems
        );

        popupAjaxError(error);
      })
      .finally(() => {
        this.model.set("sidebar_tag_names", []);
      });
  }
}
