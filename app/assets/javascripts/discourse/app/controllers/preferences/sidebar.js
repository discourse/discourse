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
    const initialSidebarTagNames = this.model.sidebarTagNames;

    this.model.set("sidebar_tag_names", this.selectedSidebarTagNames);

    this.model.set(
      "sidebarCategoryIds",
      this.selectedSidebarCategories.mapBy("id")
    );

    this.model
      .save()
      .then(() => {
        this.saved = true;
      })
      .catch((error) => {
        this.model.set("sidebarCategoryIds", initialSidebarCategoryIds);
        this.model.set("sidebar_tag_names", initialSidebarTagNames);
        popupAjaxError(error);
      });
  }
}
