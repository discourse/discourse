import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["category-drop"],
  classNameBindings: ["categoryStyle"],
  classNames: "category-drop",
  verticalOffset: 3,
  content: Ember.computed.alias("categories"),
  rowComponent: "category-row",
  headerComponent: "category-drop/category-drop-header",
  allowAutoSelectFirst: false,
  tagName: "li",
  categoryStyle: Ember.computed.alias("siteSettings.category_style"),
  noCategoriesLabel: I18n.t("categories.no_subcategory"),
  mutateAttributes() {},
  fullWidthOnMobile: true,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  subCategory: false,

  init() {
    this._super();

    if (this.get("category")) {
      this.set("value", this.get("category.id"));
    } else {
      this.set("value", null);
    }
    if (!this.get("categories")) this.set("categories", []);

    this.get("rowComponentOptions").setProperties({
      hideParentCategory: this.get("subCategory"),
      allowUncategorized: true,
      displayCategoryDescription: !(
        this.currentUser &&
        (this.currentUser.get("staff") || this.currentUser.trust_level > 0)
      )
    });
  },

  @computed("content")
  filterable(content) {
    return content && content.length >= 15;
  },

  @computed(
    "allCategoriesUrl",
    "allCategoriesLabel",
    "noCategoriesUrl",
    "noCategoriesLabel"
  )
  collectionHeader(
    allCategoriesUrl,
    allCategoriesLabel,
    noCategoriesUrl,
    noCategoriesLabel
  ) {
    let shortcuts = "";

    if (
      this.get("hasSelection") ||
      (this.get("noSubcategories") && this.get("subCategory"))
    ) {
      shortcuts += `
        <a href="${allCategoriesUrl}" class="category-filter">
          ${allCategoriesLabel}
        </a>
      `;
    }

    if (
      this.get("subCategory") &&
      (this.get("hasSelection") || !this.get("noSubcategories"))
    ) {
      shortcuts += `
        <a href="${noCategoriesUrl}" class="category-filter">
          ${noCategoriesLabel}
        </a>
      `;
    }

    return shortcuts.htmlSafe();
  },

  computeHeaderContent() {
    let content = this._super();

    if (this.get("hasSelection")) {
      const category = Category.findById(content.value);
      content.title = category.title;
      content.label = categoryBadgeHTML(category, {
        link: false,
        allowUncategorized: true,
        hideParent: true
      }).htmlSafe();
    } else {
      if (this.get("noSubcategories")) {
        content.label = `<span class="category-name">${this.get(
          "noCategoriesLabel"
        )}</span>`;
        content.title = this.get("noCategoriesLabel");
      } else {
        content.label = `<span class="category-name">${this.get(
          "allCategoriesLabel"
        )}</span>`;
        content.title = this.get("allCategoriesLabel");
      }
    }

    return content;
  },

  @computed("parentCategory.name", "subCategory")
  allCategoriesLabel(categoryName, subCategory) {
    if (subCategory) {
      return I18n.t("categories.all_subcategories", { categoryName });
    }
    return I18n.t("categories.all");
  },

  @computed("parentCategory.url", "subCategory")
  allCategoriesUrl(parentCategoryUrl, subCategory) {
    return subCategory ? parentCategoryUrl || "/" : "/";
  },

  @computed("parentCategory.url")
  noCategoriesUrl(parentCategoryUrl) {
    return `${parentCategoryUrl}/none`;
  },

  actions: {
    onSelect(categoryId) {
      const category = Category.findById(parseInt(categoryId, 10));
      const categoryURL =
        Discourse.getURL("/c/") + Discourse.Category.slugFor(category);
      DiscourseURL.routeTo(categoryURL);
    }
  }
});
