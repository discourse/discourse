import ValidState from "wizard/mixins/valid-state";

export default Ember.Object.extend(ValidState, {
  id: null,
  type: null,
  value: null,
  required: null,
  warning: null,

  check() {
    if (!this.get("required")) {
      this.setValid(true);
      return true;
    }

    const val = this.get("value");
    const valid = val && val.length > 0;

    this.setValid(valid);
    return valid;
  }
});
