import DiscourseURL from "discourse/lib/url";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import Category from "discourse/models/category";
import computed from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel("general", {
  foregroundColors: ["FFFFFF", "000000"],
  canSelectParentCategory: Em.computed.not("category.isUncategorizedCategory"),

  // background colors are available as a pipe-separated string
  @computed
  backgroundColors() {
    const categories = this.site.get("categoriesList");
    return this.siteSettings.category_colors
      .split("|")
      .map(function(i) {
        return i.toUpperCase();
      })
      .concat(
        categories.map(function(c) {
          return c.color.toUpperCase();
        })
      )
      .uniq();
  },

  @computed
  noCategoryStyle() {
    return this.siteSettings.category_style === "none";
  },

  @computed("category.id", "category.color")
  usedBackgroundColors(categoryId, categoryColor) {
    const categories = this.site.get("categoriesList");

    // If editing a category, don't include its color:
    return categories
      .map(function(c) {
        return categoryId &&
          categoryColor.toUpperCase() === c.color.toUpperCase()
          ? null
          : c.color.toUpperCase();
      }, this)
      .compact();
  },

  @computed
  parentCategories() {
    return this.site
      .get("categoriesList")
      .filter(c => !c.get("parentCategory"));
  },

  @computed(
    "category.parent_category_id",
    "category.categoryName",
    "category.color",
    "category.text_color"
  )
  categoryBadgePreview(parentCategoryId, name, color, textColor) {
    const category = this.get("category");
    const c = Category.create({
      name,
      color,
      text_color: textColor,
      parent_category_id: parseInt(parentCategoryId),
      read_restricted: category.get("read_restricted")
    });
    return categoryBadgeHTML(c, { link: false });
  },

  // We can change the parent if there are no children
  @computed("category.id")
  subCategories(categoryId) {
    if (Ember.isEmpty(categoryId)) {
      return null;
    }
    return Category.list().filterBy("parent_category_id", categoryId);
  },

  @computed("category.isUncategorizedCategory", "category.id")
  showDescription(isUncategorizedCategory, categoryId) {
    return !isUncategorizedCategory && categoryId;
  },

  actions: {
    showCategoryTopic() {
      DiscourseURL.routeTo(this.get("category.topic_url"));
      return false;
    }
  }
});
