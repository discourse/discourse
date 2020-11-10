import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  model(params) {
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
});
