import Service, { service } from "@ember/service";

/**
 * @typedef {{
 *   id: string,
 *   name: string,
 *   title: string,
 *   description: string,
 *   icon: string,
 *   available: boolean,
 *   visible: boolean,
 *   configuration_schema: Record<string, Record<string, unknown>[]>,
 *   required_plugin?: string,
 *   can_enable_plugin?: boolean,
 *   contact_admin_username?: string,
 *   [key: string]: unknown,
 * }} CategoryType
 */

/**
 * @typedef {{
 *   type: string,
 *   typeName: string,
 *   typeSchema: CategoryType["configuration_schema"],
 *   typeTitle: string,
 *   visible: boolean,
 *   available: boolean,
 *   count: number,
 * }} CategoryTypeSelection
 */

export default class CategoryTypeChooser extends Service {
  @service router;

  /** @type {CategoryTypeSelection | null} */
  _selection = null;
  _setupComplete = false;

  /** @type {CategoryType[] | null} */
  _allTypes = null;

  get allTypes() {
    return this._allTypes;
  }

  set allTypes(types) {
    this._allTypes = types;
  }

  get hasCompletedSetup() {
    return this._selection !== null || this._setupComplete;
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
    this.router.transitionTo("newCategory.setup");
  }
}
