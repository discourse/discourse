import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";

export default class extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked filter = "";
  @tracked filteredCategoryIds;
  @tracked onlySelected = false;
  @tracked onlyUnselected = false;

  @tracked selectedSidebarCategoryIds = [
    ...this.currentUser.sidebar_category_ids,
  ];

  categoryGroupings = [];

  constructor() {
    super(...arguments);

    let categories = [...this.site.categories];

    if (!this.siteSettings.fixed_category_positions) {
      categories.sort((a, b) => a.name.localeCompare(b.name));
    }

    Category.sortCategories(categories).reduce(
      (categoryGrouping, category, index, arr) => {
        if (category.isUncategorizedCategory) {
          return categoryGrouping;
        }

        categoryGrouping.push(category);

        const nextCategory = arr[index + 1];

        if (!nextCategory || nextCategory.level === 0) {
          this.categoryGroupings.push(categoryGrouping);
          return [];
        }

        return categoryGrouping;
      },
      []
    );
  }

  get filteredCategoriesGroupings() {
    const filteredCategoryIds = new Set();

    const groupings = this.categoryGroupings.reduce((acc, categoryGrouping) => {
      const filteredCategories = new Set();

      const addCategory = (category) => {
        if (this.#matchesFilter(category)) {
          if (category.parentCategory?.parentCategory) {
            filteredCategories.add(category.parentCategory.parentCategory);
          }

          if (category.parentCategory) {
            filteredCategories.add(category.parentCategory);
          }

          filteredCategoryIds.add(category.id);
          filteredCategories.add(category);
        }
      };

      categoryGrouping.forEach((category) => {
        if (this.onlySelected) {
          if (this.selectedSidebarCategoryIds.includes(category.id)) {
            addCategory(category);
          }
        } else if (this.onlyUnselected) {
          if (!this.selectedSidebarCategoryIds.includes(category.id)) {
            addCategory(category);
          }
        } else {
          addCategory(category);
        }
      });

      if (filteredCategories.size > 0) {
        acc.push(Array.from(filteredCategories));
      }

      return acc;
    }, []);

    this.filteredCategoryIds = Array.from(filteredCategoryIds);
    return groupings;
  }

  #matchesFilter(category) {
    return this.filter.length === 0 || category.nameLower.includes(this.filter);
  }

  @action
  resetFilter() {
    this.onlySelected = false;
    this.onlyUnselected = false;
  }

  @action
  filterSelected() {
    this.onlySelected = true;
    this.onlyUnselected = false;
  }

  @action
  filterUnselected() {
    this.onlySelected = false;
    this.onlyUnselected = true;
  }

  @action
  onFilterInput(filter) {
    discourseDebounce(this, this.#performFiltering, filter, INPUT_DELAY);
  }

  #performFiltering(filter) {
    this.filter = filter.toLowerCase();
  }

  @action
  deselectAll() {
    this.selectedSidebarCategoryIds.clear();
  }

  @action
  toggleCategory(categoryId) {
    if (this.selectedSidebarCategoryIds.includes(categoryId)) {
      this.selectedSidebarCategoryIds.removeObject(categoryId);
    } else {
      this.selectedSidebarCategoryIds.addObject(categoryId);
    }
  }

  @action
  resetToDefaults() {
    this.selectedSidebarCategoryIds =
      this.siteSettings.default_navigation_menu_categories
        .split("|")
        .map((id) => parseInt(id, 10));
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
