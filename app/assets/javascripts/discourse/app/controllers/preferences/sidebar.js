import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Controller {
  @tracked saved = false;
  @tracked selectedSidebarCategories = [];
  @tracked selectedSidebarTagNames = [];

  @action
  save() {
    const initialSidebarCategoryIds = this.model.sidebarCategoryIds;

    this.model.set(
      "sidebarCategoryIds",
      this.selectedSidebarCategories.mapBy("id")
    );

    this.model.set("sidebar_tag_names", this.selectedSidebarTagNames);

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
