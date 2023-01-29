import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

import { popupAjaxError } from "discourse/lib/ajax-error";

export const DEFAULT_LIST_DESTINATION = "default";
export const UNREAD_LIST_DESTINATION = "unread_new";

export default class extends Controller {
  @tracked saved = false;
  @tracked selectedSidebarCategories = [];
  @tracked selectedSidebarTagNames = [];
  subpageTitle = I18n.t("user.preferences_nav.sidebar");

  saveAttrNames = [
    "sidebar_category_ids",
    "sidebar_tag_names",
    "sidebar_list_destination",
  ];

  sidebarListDestinations = [
    {
      name: I18n.t("user.experimental_sidebar.list_destination_default"),
      value: DEFAULT_LIST_DESTINATION,
    },
    {
      name: I18n.t("user.experimental_sidebar.list_destination_unread_new"),
      value: UNREAD_LIST_DESTINATION,
    },
  ];

  @action
  save() {
    const initialSidebarCategoryIds = this.model.sidebarCategoryIds;
    const initialSidebarListDestination = this.model.sidebar_list_destination;

    this.model.set(
      "sidebarCategoryIds",
      this.selectedSidebarCategories.mapBy("id")
    );

    this.model.set("sidebar_tag_names", this.selectedSidebarTagNames);

    this.model.set(
      "user_option.sidebar_list_destination",
      this.newSidebarListDestination
    );

    this.model
      .save(this.saveAttrNames)
      .then((result) => {
        if (result.user.sidebar_tags) {
          this.model.set("sidebar_tags", result.user.sidebar_tags);
        }
        this.model.set(
          "sidebar_list_destination",
          this.newSidebarListDestination
        );

        this.saved = true;
      })
      .catch((error) => {
        this.model.set("sidebarCategoryIds", initialSidebarCategoryIds);
        popupAjaxError(error);
      })
      .finally(() => {
        this.model.set("sidebar_tag_names", []);
        if (initialSidebarListDestination !== this.newSidebarListDestination) {
          window.location.reload();
        }
      });
  }
}
