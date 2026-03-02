import Service, { service } from "@ember/service";

export default class CategoryTypeChooser extends Service {
  @service router;
  @service siteSettings;

  _selection = null;
  _setupComplete = false;

  get isEnabled() {
    return (
      this.siteSettings.enable_simplified_category_creation &&
      this.siteSettings.enable_category_type_setup
    );
  }

  get hasCompletedSetup() {
    return this._selection !== null || this._setupComplete;
  }

  choose(typeId, typeName, typeSchema) {
    this._selection = { type: typeId, typeName, typeSchema };
    this._setupComplete = true;
  }

  consume() {
    const selection = this._selection;
    this._selection = null;
    return selection;
  }

  reset() {
    this._selection = null;
    this._setupComplete = false;
  }

  createCategory() {
    if (this.isEnabled) {
      this.router.transitionTo("newCategory.setup");
      return;
    }

    if (this.router.currentRouteName === "newCategory.index") {
      this.router.refresh();
    } else {
      this.router.transitionTo("newCategory");
    }
  }
}
