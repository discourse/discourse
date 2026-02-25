import Service, { service } from "@ember/service";
import ChooseCategoryType from "discourse/components/modal/choose-category-type";

export default class CategoryTypeChooser extends Service {
  @service modal;
  @service router;
  @service siteSettings;

  _selection = null;

  choose(typeId, typeName, typeSchema) {
    this._selection = { type: typeId, typeName, typeSchema };
  }

  consume() {
    const selection = this._selection;
    this._selection = null;
    return selection;
  }

  async createCategory() {
    if (this.siteSettings.enable_simplified_category_creation) {
      const result = await this.modal.show(ChooseCategoryType);
      if (!result?.categoryType) {
        return;
      }
      this.choose(
        result.categoryType,
        result.categoryTypeName,
        result.categoryTypeSchema
      );
    }

    if (this.router.currentRouteName === "newCategory") {
      this.router.refresh();
    } else {
      this.router.transitionTo("newCategory");
    }
  }
}
