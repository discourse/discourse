import { sort } from "@ember/object/computed";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { trackedArray } from "discourse/lib/tracked-tools";

export default class AdminUserFields extends Service {
  @service store;

  @trackedArray userFields = [];

  @sort("userFields", "fieldSortOrder") sortedUserFields;

  fieldSortOrder = ["position"];

  constructor() {
    super(...arguments);

    this.#fetchUserFields();
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
