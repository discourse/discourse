import discourseComputed from "discourse-common/utils/decorators";

export const States = {
  UNCHECKED: 0,
  INVALID: 1,
  VALID: 2
};

export default {
  _validState: null,
  errorDescription: null,

  init() {
    this._super(...arguments);
    this.set("_validState", States.UNCHECKED);
  },

  @discourseComputed("_validState")
  valid: state => state === States.VALID,

  @discourseComputed("_validState")
  invalid: state => state === States.INVALID,

  @discourseComputed("_validState")
  unchecked: state => state === States.UNCHECKED,

  setValid(valid, description) {
    this.set("_validState", valid ? States.VALID : States.INVALID);

    if (!valid && description && description.length) {
      this.set("errorDescription", description);
    } else {
      this.set("errorDescription", null);
    }
  }
};
