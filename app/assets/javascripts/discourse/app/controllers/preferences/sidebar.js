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
      .save()
      .then((result) => {
        if (result.user.sidebar_tags) {
          this.model.set("sidebar_tags", result.user.sidebar_tags);
        }

        this.saved = true;
      })
      .catch((error) => {
        this.model.set("sidebarCategoryIds", initialSidebarCategoryIds);
        popupAjaxError(error);
      })
      .finally(() => {
        this.model.set("sidebar_tag_names", []);
      });
  }
}
