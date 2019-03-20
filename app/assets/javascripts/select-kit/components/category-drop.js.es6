import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
const { isEmpty } = Ember;

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["category-drop"],
  classNameBindings: ["categoryStyle"],
  classNames: "category-drop",
  verticalOffset: 3,
  content: Ember.computed.alias("categoriesWithShortcuts"),
  rowComponent: "category-row",
  headerComponent: "category-drop/category-drop-header",
  allowAutoSelectFirst: false,
  tagName: "li",
  categoryStyle: Ember.computed.alias("siteSettings.category_style"),
  noCategoriesLabel: I18n.t("categories.no_subcategory"),
  fullWidthOnMobile: true,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  subCategory: false,
  isAsync: Ember.computed.not("subCategory"),

  @computed("categories", "hasSelection", "subCategory", "noSubcategories")
  categoriesWithShortcuts(
    categories,
    hasSelection,
    subCategory,
    noSubcategories
  ) {
    const shortcuts = [];

    if (hasSelection || (noSubcategories && subCategory)) {
      shortcuts.push({
        name: this.get("allCategoriesLabel"),
        __sk_row_type: "noopRow",
        id: "all-categories"
      });
    }

    if (subCategory && (hasSelection || !noSubcategories)) {
      shortcuts.push({
        name: this.get("noCategoriesLabel"),
        __sk_row_type: "noopRow",
        id: "no-categories"
      });
    }

    return shortcuts.concat(categories);
  },

  init() {
    this._super(...arguments);

    this.get("rowComponentOptions").setProperties({
      hideParentCategory: this.get("subCategory"),
      allowUncategorized: true,
      countSubcategories: this.get("countSubcategories"),
      displayCategoryDescription: !(
        this.currentUser &&
        (this.currentUser.get("staff") || this.currentUser.trust_level > 0)
      )
    });
  },

  didReceiveAttrs() {
    if (!this.get("categories")) this.set("categories", []);
    this.forceValue(this.get("category.id"));
  },

  @computed("content")
  filterable(content) {
    const contentLength = (content && content.length) || 0;
    return (
      contentLength >= 15 ||
      (this.get("isAsync") && contentLength < Discourse.Category.list().length)
    );
  },

  computeHeaderContent() {
    let content = this._super(...arguments);

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
    return Discourse.getURL(subCategory ? parentCategoryUrl || "/" : "/");
  },

  @computed("parentCategory.url")
  noCategoriesUrl(parentCategoryUrl) {
    return Discourse.getURL(`${parentCategoryUrl}/none`);
  },

  actions: {
    onSelect(categoryId) {
      let categoryURL;

      if (categoryId === "all-categories") {
        categoryURL = Discourse.getURL(this.get("allCategoriesUrl"));
      } else if (categoryId === "no-categories") {
        categoryURL = Discourse.getURL(this.get("noCategoriesUrl"));
      } else {
        const category = Category.findById(parseInt(categoryId, 10));
        const slug = Discourse.Category.slugFor(category);
        categoryURL = Discourse.getURL("/c/") + slug;
      }

      DiscourseURL.routeTo(categoryURL);
    },

    onExpand() {
      if (this.get("isAsync") && isEmpty(this.get("asyncContent"))) {
        this.set("asyncContent", this.get("content"));
      }
    },

    onFilter(filter) {
      if (!this.get("isAsync")) {
        return;
      }

      if (isEmpty(filter)) {
        this.set("asyncContent", this.get("content"));
        return;
      }

      let results = Discourse.Category.search(filter);

      if (!this.siteSettings.allow_uncategorized_topics) {
        results = results.filter(result => {
          return (
            result.id !==
            Discourse.Site.currentProp("uncategorized_category_id")
          );
        });
      }

      results = results.sort((a, b) => {
        if (a.parent_category_id && !b.parent_category_id) {
          return 1;
        } else if (!a.parent_category_id && b.parent_category_id) {
          return -1;
        } else {
          return 0;
        }
      });

      this.set("asyncContent", results);
      this.autoHighlight();
    }
  }
});
