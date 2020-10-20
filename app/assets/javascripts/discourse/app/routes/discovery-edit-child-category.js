import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  model(params) {
    return Category.reloadBySlug(params.slug, params.parentSlug).then(
      (result) => {
        const record = this.store.createRecord("category", result.category);
        record.setupGroupsAndPermissions();
        this.site.updateCategory(record);
        return record;
      }
    );
  },

  titleToken() {
    return I18n.t("category.edit_dialog_title", {
      categoryName: this.currentModel.name,
    });
  },

  renderTemplate() {
    this.render("edit-category", {
      controller: "edit-category",
      outlet: "list-container",
      model: this.currentModel,
    });
  },
});
