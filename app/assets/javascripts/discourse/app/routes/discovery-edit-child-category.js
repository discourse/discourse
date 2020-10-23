import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  model(params) {
    // don't reload model when switching tabs
    if (this.currentModel) {
      this.currentModel.set("params", params);
      return this.currentModel;
    }

    return Category.reloadCategoryWithPermissions(
      params,
      this.store,
      this.site
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
