import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["categories-drop"],
  classNames: "categories-drop",
  classNameBindings: ["categoryStyle"],
  categoryStyle: Ember.computed.reads("siteSettings.category_style"),
  verticalOffset: 3,
  headerComponent: "category-drop/category-drop-header",
  allowAutoSelectFirst: false,
  tagName: "li",
  fullWidthOnMobile: true,
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  subCategory: false,
  isAsync: true,
  rowComponent: "category-row",

  init() {
    this._super(...arguments);

    this.rowComponentOptions.setProperties({
      hideParentCategory: false,
      allowUncategorized: true,
      category: this.subCategory || this.parentCategory,
      countSubcategories: this.countSubcategories,
      displayCategoryDescription: !(
        this.currentUser &&
        (this.currentUser.staff || this.currentUser.trust_level > 0)
      )
    });
  },

  @computed(
    "shortcuts.[]",
    "parentCategories",
    "subCategories",
    "parentCategory"
  )
  content(shortcuts, parentCategories, subCategories, parentCategory) {
    if (parentCategory && subCategories) {
      shortcuts = shortcuts.concat(subCategories);
    } else {
      shortcuts = shortcuts.concat(parentCategories);
    }

    return shortcuts;
  },

  @computed("hasSelection", "parentCategory", "subCategory", "noSubcategories")
  shortcuts(hasSelection, parentCategory, subCategory, noSubcategories) {
    const shortcuts = [];

    if (hasSelection || (noSubcategories && subCategory)) {
      shortcuts.push({
        name: I18n.t("categories.all"),
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

    if (parentCategory && !subCategory) {
      shortcuts.push(parentCategory);
    }

    if (subCategory) {
      shortcuts.push(this.parentCategory);
    }

    return shortcuts;
  },

  didReceiveAttrs() {
    this._super(...arguments);

    const category = this.subCategory || this.parentCategory;
    if (category) {
      this.forceValue(category.id);
    }
  },

  @computed("content")
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
      let title = this.get("parentCategory.title");
      if (this.subCategory) {
        title = `${title} ${this.get("subCategory.title")}`;
      }

      let label = categoryBadgeHTML(this.parentCategory, {
        link: false,
        allowUncategorized: true,
        hideParent: true
      }).htmlSafe();
      if (this.subCategory) {
        const subLabel = categoryBadgeHTML(this.subCategory, {
          link: false,
          allowUncategorized: true,
          hideParent: true
        }).htmlSafe();
        label += subLabel;
      }

      content.title = title;
      content.label = label;
    } else {
      if (this.noSubcategories) {
        content.label = `<span class="category-name">${this.noCategoriesLabel}</span>`;
        content.title = this.noCategoriesLabel;
      } else {
        content.label = `<span class="category-name">${I18n.t(
          "categories.all"
        )}</span>`;
        content.title = I18n.t("categories.all");
      }
    }

    return content;
  },

  noCategoriesLabel: I18n.t("categories.no_subcategory"),

  @computed("parentCategory.url")
  noCategoriesUrl(parentCategoryUrl) {
    return Discourse.getURL(`${parentCategoryUrl}/none`);
  },

  actions: {
    onExpand() {
      if (this.isAsync && Ember.isEmpty(this.asyncContent)) {
        this.set("asyncContent", this.content);
      }
    },

    onSelect(categoryId) {
      let categoryURL;

      if (categoryId === "all-categories") {
        categoryURL = Discourse.getURL("/");
      } else if (categoryId === "no-categories") {
        categoryURL = Discourse.getURL(this.noCategoriesUrl);
      } else {
        const category = Category.findById(parseInt(categoryId, 10));
        const slug = Discourse.Category.slugFor(category);
        categoryURL = `${Discourse.getURL("/c/")}${slug}`;
      }

      DiscourseURL.routeTo(categoryURL);
    },

    onFilter(filter) {
      if (!this.isAsync) {
        return;
      }

      if (Ember.isEmpty(filter)) {
        this.set("asyncContent", this.content);
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
