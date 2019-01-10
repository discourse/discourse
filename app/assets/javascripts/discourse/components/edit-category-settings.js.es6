import { setting } from "discourse/lib/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import computed from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel("settings", {
  emailInEnabled: setting("email_in"),
  showPositionInput: setting("fixed_category_positions"),
  isParentCategory: Ember.computed.empty("category.parent_category_id"),
  showSubcategoryListStyle: Ember.computed.and(
    "category.show_subcategory_list",
    "isParentCategory"
  ),
  isDefaultSortOrder: Ember.computed.empty("category.sort_order"),

  @computed
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

  @computed
  availableViews() {
    return [
      { name: I18n.t("filters.latest.title"), value: "latest" },
      { name: I18n.t("filters.top.title"), value: "top" }
    ];
  },

  @computed
  availableTopPeriods() {
    return ["all", "yearly", "quarterly", "monthly", "weekly", "daily"].map(
      p => {
        return { name: I18n.t(`filters.top.${p}.title`), value: p };
      }
    );
  },

  @computed
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
      .map(s => ({ name: I18n.t("category.sort_options." + s), value: s }))
      .sort((a, b) => {
        return a.name > b.name;
      });
  },

  @computed
  sortAscendingOptions() {
    return [
      { name: I18n.t("category.sort_ascending"), value: "true" },
      { name: I18n.t("category.sort_descending"), value: "false" }
    ];
  }
});
