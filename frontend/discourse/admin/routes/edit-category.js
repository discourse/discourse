import { service } from "@ember/service";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class EditCategory extends DiscourseRoute {
  @service router;

  model(params) {
    return this.site.lazy_load_categories
      ? Category.asyncFindBySlugPath(params.slug, { includePermissions: true })
      : Category.reloadCategoryWithPermissions(params, this.store, this.site);
  }

  async afterModel(model) {
    if (!model.can_edit) {
      this.router.replaceWith("/404");
      return;
    }

    // Load parent category permissions if this is a subcategory
    if (model.parent_category_id) {
      const parentCategory = Category.findById(model.parent_category_id);
      if (parentCategory && !parentCategory.permissions?.length) {
        const result = await Category.reloadById(model.parent_category_id);
        const updatedParent = this.site.updateCategory(result.category);
        updatedParent.setupGroupsAndPermissions();
      }
    }
  }

  titleToken() {
    return i18n("category.edit_dialog_title", {
      categoryName: this.currentModel.name,
    });
  }
}
