import EmberObject from "@ember/object";
import ValidState from "wizard/mixins/valid-state";

export default EmberObject.extend(ValidState, {
  id: null,
  type: null,
  value: null,
  required: null,
  warning: null,

  check() {
    if (!this.required) {
      this.setValid(true);
      return true;
    }

    const val = this.value;
    const valid = val && val.length > 0;

    this.setValid(valid);
    return valid;
  }
});
