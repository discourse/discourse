import EmberObject, { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import Category from "discourse/models/category";
import CategoryRow from "discourse/select-kit/components/category-row";
import MultiSelectComponent from "discourse/select-kit/components/multi-select";
import { i18n } from "discourse-i18n";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";
import SelectedChoiceCategory from "./selected-choice-category";

export const MAX_UNSELECTED_RESULTS = 30;
export const LIMITED_RESULTS_NOTICE_VALUE =
  "multiple-categories-selector-limited-results-notice";

// Multi-select category picker. Unlike `category-selector`, it caps the
// number of unselected categories rendered when there's no search text
// (search still matches the full list), so opening the dropdown stays fast
// on sites with thousands of categories. It also never uses
// `lazy_load_categories`, since that feature may be removed.
@classNames("multiple-categories-selector")
@selectKitOptions({
  filterable: true,
  allowAny: false,
  allowUncategorized: true,
  displayCategoryDescription: false,
  selectedChoiceComponent: SelectedChoiceCategory,
})
@pluginApiIdentifiers(["multiple-categories-selector"])
export default class MultipleCategoriesSelector extends MultiSelectComponent {
  categories = null;
  blockedCategories = null;

  init() {
    super.init(...arguments);

    if (!this.blockedCategories) {
      this.set("blockedCategories", []);
    }
  }

  @computed("categories.@each.id")
  get value() {
    return this.categories?.map?.((item) => item.id) ?? [];
  }

  @computed("categories.[]", "blockedCategories.[]")
  get content() {
    return Category.list().filter((category) => {
      if (category.isUncategorizedCategory) {
        if (this.options?.allowUncategorized !== undefined) {
          return this.options.allowUncategorized;
        }

        return this.selectKit.options.allowUncategorized;
      }

      return (
        this.categories.includes(category) ||
        !this.blockedCategories.includes(category)
      );
    });
  }

  modifyComponentForRow() {
    return CategoryRow;
  }

  search(filter) {
    let categories = super.search(filter);

    let uncappedTotal = null;
    if (!filter && categories.length > MAX_UNSELECTED_RESULTS) {
      uncappedTotal = categories.length;
      categories = categories.slice(0, MAX_UNSELECTED_RESULTS);
    }

    if (filter && filter.length >= 2) {
      categories = categories.flatMap((category) => {
        if (!category.has_children) {
          return [category];
        }

        return [
          category,
          EmberObject.create({
            id: `${category.id}+subcategories`,
            category,
          }),
        ];
      });
    }

    if (uncappedTotal) {
      categories.push(
        EmberObject.create({
          id: LIMITED_RESULTS_NOTICE_VALUE,
          label: i18n(
            "select_kit.components.multiple_categories_selector.limited_results_notice",
            { shown: MAX_UNSELECTED_RESULTS, count: uncappedTotal }
          ),
        })
      );
    }

    return categories;
  }

  select(value, item) {
    if (item?.category) {
      this.selectKit.change(
        makeArray(this.value).concat(
          item.category.descendants.map((subcategory) => subcategory.id)
        ),
        makeArray(this.selectedContent).concat(item.category.descendants)
      );
    } else if (item?.id === LIMITED_RESULTS_NOTICE_VALUE) {
      return;
    } else {
      super.select(value, item);
    }
  }

  @action
  _onChange(values) {
    this.onChange(values.map((v) => Category.findById(v)).filter(Boolean));
    return false;
  }
}
