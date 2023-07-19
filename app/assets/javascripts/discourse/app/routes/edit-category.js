import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  model(params) {
    return Category.reloadCategoryWithPermissions(
      params,
      this.store,
      this.site
    );
  },

  afterModel(model) {
    if (!model.can_edit) {
      this.router.replaceWith("/404");
      return;
    }
  },

  titleToken() {
    return I18n.t("category.edit_dialog_title", {
      categoryName: this.currentModel.name,
    });
  },
});
