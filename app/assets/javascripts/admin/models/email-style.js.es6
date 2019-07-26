import RestModel from "discourse/models/rest";

export default RestModel.extend({
  changed: false,

  setField(fieldName, value) {
    this.set(`${fieldName}`, value);
    this.set("changed", true);
  }
});
