import ComboBoxComponent from "select-box-kit/components/combo-box";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { observes, on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import PermissionType from "discourse/models/permission-type";
import Category from "discourse/models/category";

export default ComboBoxComponent.extend({
  classNames: "category-select-box",

  filterable: true,

  castInteger: true,

  allowUncategorized: null,

  filterFunction(content) {
    const _matchFunction = (filter, text) => {
      return text.toLowerCase().indexOf(filter) > -1;
    };

    return (selectBox) => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(content, (c) => {
        const category = Category.findById(c.get("value"));
        const text = c.get("name");
        if (category && category.get("parentCategory")) {
          const categoryName = category.get("parentCategory.name");
          return _matchFunction(filter, text) || _matchFunction(filter, categoryName);
        } else {
          return _matchFunction(filter, text);
        }
      });
    };
  },

  @computed("rootNone", "rootNoneLabel")
  none(rootNone, rootNoneLabel) {
    if (this.siteSettings.allow_uncategorized_topics || this.get("allowUncategorized")) {
      if (!Ember.isNone(rootNone)) {
        return rootNoneLabel || "category.none";
      } else {
        return Category.findUncategorized();
      }
    } else {
      return "category.choose";
    }
  },

  @computed
  templateForRow() {
    return (rowComponent) => this._rowContentTemplate(rowComponent.get("content"));
  },

  @computed
  templateForNoneRow() {
    return (rowComponent) => this._rowContentTemplate(rowComponent.get("content"));
  },

  @computed("scopedCategoryId", "categories.[]")
  content(scopedCategoryId, categories) {

    console.log("computing content", categories)
    if (Ember.isNone(categories)) {
      return;
    }

    // Always scope to the parent of a category, if present
    if (scopedCategoryId) {
      const scopedCat = Category.findById(scopedCategoryId);
      scopedCategoryId = scopedCat.get("parent_category_id") || scopedCat.get("id");
    }

    const excludeCategoryId = this.get("excludeCategoryId");

    const content = categories.filter(c => {
      const categoryId = c.get('id');
      if (scopedCategoryId && categoryId !== scopedCategoryId && c.get('parent_category_id') !== scopedCategoryId) { return false; }
      if (c.get('isUncategorizedCategory') || excludeCategoryId === categoryId) { return false; }
      return c.get('permission') === PermissionType.FULL;
    });

    return content;
  },

  @on("didRender")
  _bindComposerResizing() {
    this.appEvents.on("composer:resized", this, this.applyDirection);
  },

  @on("willDestroyElement")
  _unbindComposerResizing() {
    this.appEvents.off("composer:resized");
  },

  @computed("site.sortedCategories")
  categories() {
    return Discourse.SiteSettings.fixed_category_positions_on_create ?
                      Category.list() :
                      Category.listByActivity();
  },

  _rowContentTemplate(item) {
    let category;

    // If we have no id, but text with the uncategorized name, we can use that badge.
    if (Ember.isEmpty(item.value)) {
      const uncat = Category.findUncategorized();
      if (uncat && uncat.get("name") === item.name) {
        category = uncat;
      }
    } else {
      category = Category.findById(parseInt(item.value,10));
    }

    if (!category) return item.name;
    let result = categoryBadgeHTML(category, {link: false, allowUncategorized: true, hideParent: true});
    const parentCategoryId = category.get("parent_category_id");

    if (parentCategoryId) {
      result = `<div class="category-status">${categoryBadgeHTML(Category.findById(parentCategoryId), {link: false})}&nbsp;${result}`;
    } else {
      result = `<div class="category-status">${result}`;
    }

    result += ` <span class="topic-count">&times; ${category.get("topic_count")}</span></div>`;

    const description = category.get("description");
    // TODO wtf how can this be null?;
    if (description && description !== "null") {
      result += `<div class="category-desc">${description.substr(0, 200)}${description.length > 200 ? '&hellip;' : ''}</div>`;
    }

    return result;
  }
});
