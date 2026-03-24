import Service, { service } from "@ember/service";

export default class CategoryTypeChooser extends Service {
  @service router;
  @service siteSettings;

  _selection = null;
  _setupComplete = false;

  get isEnabled() {
    return this.siteSettings.enable_simplified_category_creation;
  }

  get hasCompletedSetup() {
    return this._selection !== null || this._setupComplete;
  }

  choose(typeId, typeName, typeSchema, typeTitle, count) {
    this._selection = { type: typeId, typeName, typeSchema, typeTitle, count };
    this._setupComplete = true;
  }

  currentSelection() {
    return this._selection;
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
