import EmberObject from "@ember/object";
import ValidState from "wizard/mixins/valid-state";
import { ajax } from "wizard/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

export default EmberObject.extend(ValidState, {
  id: null,

  @discourseComputed("index")
  displayIndex: (index) => index + 1,

  @discourseComputed("fields.[]")
  fieldsById(fields) {
    const lookup = {};
    fields.forEach((field) => (lookup[field.get("id")] = field));
    return lookup;
  },

  validate() {
    let allValid = true;
    const result = { warnings: [] };

    this.fields.forEach((field) => {
      allValid = allValid && field.check();
      const warning = field.get("warning");
      if (warning) {
        result.warnings.push(warning);
      }
    });

    this.setValid(allValid);

    return result;
  },

  fieldError(id, description) {
    const field = this.fields.findBy("id", id);
    if (field) {
      field.setValid(false, description);
    }
  },

  save() {
    const fields = {};
    this.fields.forEach((f) => (fields[f.id] = f.value));

    return ajax({
      url: `/wizard/steps/${this.id}`,
      type: "PUT",
      data: { fields },
    }).catch((response) => {
      response.responseJSON.errors.forEach((err) =>
        this.fieldError(err.field, err.description)
      );
    });
  },
});
