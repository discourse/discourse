import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

import { popupAjaxError } from "discourse/lib/ajax-error";

export default class extends Component {
  @service site;
  @service currentUser;

  @tracked selectedSidebarCategoryIds = [
    ...this.currentUser.sidebar_category_ids,
  ];

  @tracked siteCategories = this.site.categoriesList.filter((category) => {
    return !category.parent_category_id && !category.isUncategorizedCategory;
  });

  @action
  toggleCategory(categoryId) {
    if (this.selectedSidebarCategoryIds.includes(categoryId)) {
      this.selectedSidebarCategoryIds.removeObject(categoryId);
    } else {
      this.selectedSidebarCategoryIds.addObject(categoryId);
    }
  }

  @action
  save() {
    this.saving = true;
    const initialSidebarCategoryIds = this.currentUser.sidebar_category_ids;

    this.currentUser.set(
      "sidebar_category_ids",
      this.selectedSidebarCategoryIds
    );

    this.currentUser
      .save(["sidebar_category_ids"])
      .then(() => {
        this.args.closeModal();
      })
      .catch((error) => {
        this.currentUser.set("sidebar_category_ids", initialSidebarCategoryIds);
        popupAjaxError(error);
      })
      .finally(() => {
        this.saving = false;
      });
  }
}
