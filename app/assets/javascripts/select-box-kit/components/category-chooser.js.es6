import ComboBoxComponent from "select-box-kit/components/combo-box";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import PermissionType from "discourse/models/permission-type";
import Category from "discourse/models/category";
const { get, isNone, isEmpty } = Ember;

export default ComboBoxComponent.extend({
  classNames: "category-chooser",
  filterable: true,
  castInteger: true,
  allowUncategorized: null,

  filterFunction(computedContent) {
    const _matchFunction = (filter, text) => {
      return text.toLowerCase().indexOf(filter) > -1;
    };

    return (selectBox) => {
      const filter = selectBox.get("filter").toLowerCase();
      return _.filter(computedContent, c => {
        const category = Category.findById(get(c, "value"));
        const text = get(c, "name");
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
      if (!isNone(rootNone)) {
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
    return rowComponent => this._rowContentTemplate(rowComponent.get("content"));
  },

  @computed
  templateForNoneRow() {
    return rowComponent => this._rowContentTemplate(rowComponent.get("content"));
  },

  @computed("scopedCategoryId", "content.[]")
  computedContent(scopedCategoryId, categories) {
    // Always scope to the parent of a category, if present
    if (scopedCategoryId) {
      const scopedCat = Category.findById(scopedCategoryId);
      scopedCategoryId = scopedCat.get("parent_category_id") || scopedCat.get("id");
    }

    const excludeCategoryId = this.get("excludeCategoryId");

    return categories.filter(c => {
      const categoryId = get(c, "value");
      if (scopedCategoryId && categoryId !== scopedCategoryId && get(c, "originalContent.parent_category_id") !== scopedCategoryId) {
        return false;
      }
      if (get(c, 'originalContent.isUncategorizedCategory') || excludeCategoryId === categoryId) {
        return false;
      }
      return get(c, 'originalContent.permission') === PermissionType.FULL;
    });
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
  content() {
    const categories =  Discourse.SiteSettings.fixed_category_positions_on_create ?
                          Category.list() :
                          Category.listByActivity();
    return this.formatContents(categories);
  },

  _rowContentTemplate(content) {
    let category;

    // If we have no id, but text with the uncategorized name, we can use that badge.
    if (isEmpty(get(content, "value"))) {
      const uncat = Category.findUncategorized();
      if (uncat && uncat.get("name") === get(content, "name")) {
        category = uncat;
      }
    } else {
      category = Category.findById(parseInt(get(content, "value"), 10));
    }

    if (!category) return get(content, "name");
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
