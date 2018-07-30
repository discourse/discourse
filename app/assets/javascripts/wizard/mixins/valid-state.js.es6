import computed from "ember-addons/ember-computed-decorators";

export const States = {
  UNCHECKED: 0,
  INVALID: 1,
  VALID: 2
};

export default {
  _validState: null,
  errorDescription: null,

  init() {
    this._super();
    this.set("_validState", States.UNCHECKED);
  },

  @computed("_validState") valid: state => state === States.VALID,

  @computed("_validState") invalid: state => state === States.INVALID,

  @computed("_validState") unchecked: state => state === States.UNCHECKED,

  setValid(valid, description) {
    this.set("_validState", valid ? States.VALID : States.INVALID);

    if (!valid && description && description.length) {
      this.set("errorDescription", description);
    } else {
      this.set("errorDescription", null);
    }
  }
};
