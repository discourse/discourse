import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { arraySortedByProperties } from "discourse/lib/array-tools";
import { trackedArray } from "discourse/lib/tracked-tools";

export default class AdminUserFields extends Service {
  @service store;

  @tracked fieldSortOrder = ["position"];
  @trackedArray userFields = [];

  constructor() {
    super(...arguments);

    this.#fetchUserFields();
  }

  @dependentKeyCompat
  get sortedUserFields() {
    return arraySortedByProperties(this.userFields, this.fieldSortOrder);
  }

  async #fetchUserFields() {
    try {
      const userFields = await this.store.findAll("user-field");
      this.userFields = userFields.content;
    } catch (err) {
      popupAjaxError(err);
    }
  }

  get firstField() {
    return this.sortedUserFields[0];
  }

  get lastField() {
    return this.sortedUserFields[this.sortedUserFields.length - 1];
  }
}
