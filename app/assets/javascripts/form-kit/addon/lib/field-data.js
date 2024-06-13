import { tracked } from "@glimmer/tracking";
import ValidationParser from "form-kit/lib/validation-parser";
import Validator from "form-kit/lib/validator";
import uniqueId from "discourse/helpers/unique-id";

export default class FieldData {
  /**
   * tracked state that enabled a dynamic validation of a field *before* the whole form is submitted, e.g. by `@validateOn="blur" and the blur event being triggered for that particular field.
   */
  @tracked validationEnabled = false;

  id = uniqueId();

  errorId = uniqueId;

  constructor(name, fieldRegistration) {
    this.name = name;
    this.fieldRegistration = fieldRegistration;
    this.onSet = fieldRegistration.onSet;

    this.rules = this.fieldRegistration.validation
      ? ValidationParser.parse(fieldRegistration.validation)
      : null;
  }

  get disabled() {
    return this.fieldRegistration.disabled;
  }

  get required() {
    return this.rules?.required ?? false;
  }

  get maxLength() {
    return this.rules?.length?.max ?? null;
  }

  /**
   * The *field* level validation callback passed to the field as in `<form.field @name="foo" @validate={{this.validateCallback}}>`
   */

  async validate(name, value, data) {
    if (this.fieldRegistration.disabled) {
      return;
    }

    const validator = new Validator(
      value,
      this.fieldRegistration.type,
      this.rules
    );

    await this.fieldRegistration.validate?.(
      name,
      value,
      data,
      validator.addError
    );
    await validator.validate();

    return {
      [name]: validator.errors,
    };
  }
}
