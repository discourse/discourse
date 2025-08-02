import { tracked } from "@glimmer/tracking";
import { sort } from "@ember/object/computed";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminUserFields extends Service {
  @service store;

  @tracked userFields = [];

  @sort("userFields", "fieldSortOrder") sortedUserFields;

  fieldSortOrder = ["position"];

  constructor() {
    super(...arguments);

    this.#fetchUserFields();
  }

  async #fetchUserFields() {
    try {
      this.userFields = await this.store.findAll("user-field");
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
