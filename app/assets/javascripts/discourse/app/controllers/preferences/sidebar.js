import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Controller {
  @tracked saved = false;
  @tracked selectedSiderbarCategories = [];
  @tracked selectedSidebarTagNames = [];

  @action
  tagUpdated(tagNames) {
    this.selectedSidebarTagNames = tagNames;
    this.model.set("sidebar_tag_names", tagNames);
    this.saved = false;
  }

  @action
  categoryUpdated(categories) {
    this.selectedSiderbarCategories = categories;
    this.model.set("sidebarCategoryIds", categories.mapBy("id"));
    this.saved = false;
  }

  @action
  save() {
    this.model
      .save()
      .then(() => {
        this.saved = true;
        this.initialSidebarCategoryIds = this.model.sidebarCategoryIds;
        this.initialSidebarTagNames = this.model.initialSidebarTagNames;
      })
      .catch((error) => {
        this.model.set("sidebarCategoryIds", this.initialSidebarCategoryIds);
        this.model.set("sidebar_tag_names", this.initialSidebarTagNames);
        popupAjaxError(error);
      });
  }
}
