import { tracked } from "@glimmer/tracking";
import ValidationParser from "form-kit/lib/validation-parser";
import Validator from "form-kit/lib/validator";

export default class FieldData {
  /**
   * tracked state that enabled a dynamic validation of a field *before* the whole form is submitted, e.g. by `@validateOn="blur" and the blur event being triggered for that particular field.
   */
  @tracked validationEnabled = false;

  constructor(fieldRegistration) {
    this.fieldRegistration = fieldRegistration;

    this.rules = this.fieldRegistration.validation
      ? ValidationParser.parse(fieldRegistration.validation)
      : null;
  }

  get required() {
    console.log("requiredrules", this.rules);
    return this.rules?.required ?? false;
  }

  /**
   * The *field* level validation callback passed to the field as in `<form.field @name="foo" @validate={{this.validateCallback}}>`
   */

  async validate(value) {
    if (this.fieldRegistration.disabled) {
      return;
    }

    let primitiveType;
    switch (this.fieldRegistration.type) {
      case "number":
        primitiveType = "number";
        return;
      case "checkbox":
        primitiveType = "boolean";
        return;
      default:
        primitiveType = "string";
    }

    return Validator.validate(value, primitiveType, this.rules ?? {});
  }
}
