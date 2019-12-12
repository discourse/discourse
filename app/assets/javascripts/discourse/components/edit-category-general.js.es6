import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { not } from "@ember/object/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import Category from "discourse/models/category";

export default buildCategoryPanel("general", {
  init() {
    this._super(...arguments);

    this.foregroundColors = ["FFFFFF", "000000"];
  },

  canSelectParentCategory: not("category.isUncategorizedCategory"),
  uncategorizedSiteSettingLink: Discourse.getURL(
    "/admin/site_settings/category/all_results?filter=allow_uncategorized_topics"
  ),
  customizeTextContentLink: Discourse.getURL(
    "/admin/customize/site_texts?q=uncategorized"
  ),

  // background colors are available as a pipe-separated string
  @discourseComputed
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

  @discourseComputed
  noCategoryStyle() {
    return this.siteSettings.category_style === "none";
  },

  @discourseComputed("category.id", "category.color")
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

  @discourseComputed
  parentCategories() {
    return this.site
      .get("categoriesList")
      .filter(c => c.level + 1 < Discourse.SiteSettings.max_category_nesting);
  },

  @discourseComputed(
    "category.parent_category_id",
    "category.categoryName",
    "category.color",
    "category.text_color"
  )
  categoryBadgePreview(parentCategoryId, name, color, textColor) {
    const category = this.category;
    const c = Category.create({
      name,
      color,
      text_color: textColor,
      parent_category_id: parseInt(parentCategoryId, 10),
      read_restricted: category.get("read_restricted")
    });
    return categoryBadgeHTML(c, { link: false });
  },

  // We can change the parent if there are no children
  @discourseComputed("category.id")
  subCategories(categoryId) {
    if (isEmpty(categoryId)) {
      return null;
    }
    return Category.list().filterBy("parent_category_id", categoryId);
  },

  @discourseComputed("category.isUncategorizedCategory", "category.id")
  showDescription(isUncategorizedCategory, categoryId) {
    return !isUncategorizedCategory && categoryId;
  },

  actions: {
    showCategoryTopic() {
      window.open(this.get("category.topic_url"), "_blank").focus();
      return false;
    }
  }
});
