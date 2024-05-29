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
    return this.rules?.required ?? false;
  }

  /**
   * The *field* level validation callback passed to the field as in `<form.field @name="foo" @validate={{this.validateCallback}}>`
   */

  async validate(value) {
    return Validator.validate(
      value,
      this.fieldRegistration.type,
      this.rules ?? {}
    );
  }
}
