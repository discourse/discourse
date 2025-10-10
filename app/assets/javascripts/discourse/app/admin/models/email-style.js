import RestModel from "discourse/models/rest";

export default class EmailStyle extends RestModel {
  changed = false;

  setField(fieldName, value) {
    this.set(`${fieldName}`, value);
    this.set("changed", true);
  }
}
