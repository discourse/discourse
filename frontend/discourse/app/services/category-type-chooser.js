import Service, { service } from "@ember/service";

export default class CategoryTypeChooser extends Service {
  @service router;
  @service siteSettings;

  _selection = null;
  _setupComplete = false;
  _allTypes = null;

  get isEnabled() {
    return this.siteSettings.enable_simplified_category_creation;
  }

  get hasCompletedSetup() {
    return this._selection !== null || this._setupComplete;
  }

  get allTypes() {
    return this._allTypes;
  }

  set allTypes(types) {
    this._allTypes = types;
  }

  get currentSelection() {
    return this._selection;
  }

  choose(type, count) {
    this._selection = {
      type: type.id,
      typeName: type.name,
      typeSchema: type.configuration_schema,
      typeTitle: type.title,
      visible: type.visible,
      available: type.available,
      count,
    };
    this._setupComplete = true;
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
