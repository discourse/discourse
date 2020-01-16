import { alias, not } from "@ember/object/computed";
import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import discourseComputed from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import Site from "discourse/models/site";

const { isEmpty } = Ember;

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["category-drop"],
  classNameBindings: ["categoryStyle"],
  classNames: "category-drop",
  verticalOffset: 3,
  content: alias("categoriesWithShortcuts"),
  rowComponent: "category-row",
  headerComponent: "category-drop/category-drop-header",
  allowAutoSelectFirst: false,
  tagName: "li",
  categoryStyle: alias("siteSettings.category_style"),
  noCategoriesLabel: I18n.t("categories.no_subcategory"),
  fullWidthOnMobile: true,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  subCategory: false,
  isAsync: not("subCategory"),

  @discourseComputed(
    "categories",
    "hasSelection",
    "subCategory",
    "noSubcategories"
  )
  categoriesWithShortcuts(
    categories,
    hasSelection,
    subCategory,
    noSubcategories
  ) {
    const shortcuts = [];

    if (hasSelection || (noSubcategories && subCategory)) {
      shortcuts.push({
        name: this.allCategoriesLabel,
        __sk_row_type: "noopRow",
        id: "all-categories"
      });
    }

    if (subCategory && (hasSelection || !noSubcategories)) {
      shortcuts.push({
        name: this.noCategoriesLabel,
        __sk_row_type: "noopRow",
        id: "no-categories"
      });
    }

    return shortcuts.concat(categories);
  },

  init() {
    this._super(...arguments);

    this.rowComponentOptions.setProperties({
      hideParentCategory: this.subCategory,
      allowUncategorized: true,
      countSubcategories: this.countSubcategories,
      displayCategoryDescription: !(
        this.currentUser &&
        (this.currentUser.get("staff") || this.currentUser.trust_level > 0)
      )
    });
  },

  didReceiveAttrs() {
    if (!this.categories) this.set("categories", []);
    this.forceValue(this.get("category.id"));
  },

  @discourseComputed("content")
  filterable(content) {
    const contentLength = (content && content.length) || 0;
    return (
      contentLength >= 15 ||
      (this.isAsync && contentLength < Category.list().length)
    );
  },

  computeHeaderContent() {
    let content = this._super(...arguments);

    if (this.hasSelection) {
      const category = Category.findById(content.value);
      content.title = category.title;
      content.label = categoryBadgeHTML(category, {
        link: false,
        allowUncategorized: true,
        hideParent: true
      }).htmlSafe();
    } else {
      if (this.noSubcategories) {
        content.label = `<span class="category-name">${this.get(
          "noCategoriesLabel"
        )}</span>`;
        content.title = this.noCategoriesLabel;
      } else {
        content.label = `<span class="category-name">${this.get(
          "allCategoriesLabel"
        )}</span>`;
        content.title = this.allCategoriesLabel;
      }
    }

    return content;
  },

  @discourseComputed("parentCategory.name", "subCategory")
  allCategoriesLabel(categoryName, subCategory) {
    if (subCategory) {
      return I18n.t("categories.all_subcategories", { categoryName });
    }
    return I18n.t("categories.all");
  },

  @discourseComputed("parentCategory.url", "subCategory")
  allCategoriesUrl(parentCategoryUrl, subCategory) {
    return Discourse.getURL(subCategory ? parentCategoryUrl || "/" : "/");
  },

  @discourseComputed("parentCategory.url")
  noCategoriesUrl(parentCategoryUrl) {
    return Discourse.getURL(`${parentCategoryUrl}/none`);
  },

  actions: {
    onSelect(categoryId) {
      let categoryURL;

      if (categoryId === "all-categories") {
        categoryURL = Discourse.getURL(this.allCategoriesUrl);
      } else if (categoryId === "no-categories") {
        categoryURL = Discourse.getURL(this.noCategoriesUrl);
      } else {
        const category = Category.findById(parseInt(categoryId, 10));
        const slug = Category.slugFor(category);
        categoryURL = Discourse.getURL(`/c/${slug}/${categoryId}`);
      }

      DiscourseURL.routeTo(categoryURL);
    },

    onExpand() {
      if (this.isAsync && isEmpty(this.asyncContent)) {
        this.set("asyncContent", this.content);
      }
    },

    onFilter(filter) {
      if (!this.isAsync) {
        return;
      }

      if (isEmpty(filter)) {
        this.set("asyncContent", this.content);
        return;
      }

      let results = Category.search(filter);

      if (!this.siteSettings.allow_uncategorized_topics) {
        results = results.filter(result => {
          return result.id !== Site.currentProp("uncategorized_category_id");
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
