import discourseComputed from "discourse-common/utils/decorators";
import { empty, and } from "@ember/object/computed";
import { setting } from "discourse/lib/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { searchPriorities } from "discourse/components/concerns/category-search-priorities";
import Group from "discourse/models/group";

const categorySortCriteria = [];
export function addCategorySortCriteria(criteria) {
  categorySortCriteria.push(criteria);
}

export default buildCategoryPanel("settings", {
  emailInEnabled: setting("email_in"),
  showPositionInput: setting("fixed_category_positions"),
  @discourseComputed("category.isParent", "category.parent_category_id")
  isParentCategory(isParent, parentCategoryId) {
    return isParent || !parentCategoryId;
  },
  showSubcategoryListStyle: and(
    "category.show_subcategory_list",
    "isParentCategory"
  ),
  isDefaultSortOrder: empty("category.sort_order"),

  @discourseComputed
  availableSubcategoryListStyles() {
    return [
      { name: I18n.t("category.subcategory_list_styles.rows"), value: "rows" },
      {
        name: I18n.t(
          "category.subcategory_list_styles.rows_with_featured_topics"
        ),
        value: "rows_with_featured_topics"
      },
      {
        name: I18n.t("category.subcategory_list_styles.boxes"),
        value: "boxes"
      },
      {
        name: I18n.t(
          "category.subcategory_list_styles.boxes_with_featured_topics"
        ),
        value: "boxes_with_featured_topics"
      }
    ];
  },

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  @discourseComputed
  availableViews() {
    return [
      { name: I18n.t("filters.latest.title"), value: "latest" },
      { name: I18n.t("filters.top.title"), value: "top" }
    ];
  },

  @discourseComputed
  availableTopPeriods() {
    return ["all", "yearly", "quarterly", "monthly", "weekly", "daily"].map(
      p => {
        return { name: I18n.t(`filters.top.${p}.title`), value: p };
      }
    );
  },

  @discourseComputed
  searchPrioritiesOptions() {
    const options = [];

    Object.entries(searchPriorities).forEach(entry => {
      const [name, value] = entry;

      options.push({
        name: I18n.t(`category.search_priority.options.${name}`),
        value
      });
    });

    return options;
  },

  @discourseComputed
  availableSorts() {
    return [
      "likes",
      "op_likes",
      "views",
      "posts",
      "activity",
      "posters",
      "category",
      "created"
    ]
      .concat(categorySortCriteria)
      .map(s => ({ name: I18n.t("category.sort_options." + s), value: s }))
      .sort((a, b) => a.name.localeCompare(b.name));
  },

  @discourseComputed
  sortAscendingOptions() {
    return [
      { name: I18n.t("category.sort_ascending"), value: "true" },
      { name: I18n.t("category.sort_descending"), value: "false" }
    ];
  }
});
