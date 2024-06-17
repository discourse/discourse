import { tracked } from "@glimmer/tracking";
import ValidationParser from "discourse/form-kit/lib/validation-parser";
import Validator from "discourse/form-kit/lib/validator";
import uniqueId from "discourse/helpers/unique-id";

/**
 * Represents field data for a form.
 */
export default class FieldData {
  @tracked validationEnabled;

  /**
   * Unique identifier for the field.
   * @type {string}
   */
  id = uniqueId();

  /**
   * Unique identifier for the field error.
   * @type {Function}
   */
  errorId = uniqueId;

  /**
   * Creates an instance of FieldData.
   * @param {string} name - The name of the field.
   * @param {Object} options - The options for the field.
   * @param {Function} options.set - The callback function for setting the field value.
   * @param {Function} options.onSet - The callback function for setting the custom field value.
   * @param {string} options.validation - The validation rules for the field.
   * @param {boolean} options.disabled - Indicates if the field is disabled.
   * @param {Function} options.validate - The custom validation function.
   */
  constructor(
    name,
    { set, onSet, validation, disabled, validate, validationEnabled }
  ) {
    this.name = name;
    this.disabled = disabled ?? false;
    this.customValidate = validate;
    this.validation = validation;
    this.rules = this.validation ? ValidationParser.parse(validation) : null;
    this.validationEnabled = validationEnabled ?? true;
    this.set = (value) => {
      if (onSet) {
        onSet(value, { set });
      } else {
        set(this.name, value);
      }
    };
  }

  /**
   * Checks if the field is required.
   * @type {boolean}
   * @readonly
   */
  get required() {
    return this.rules?.required ?? false;
  }

  /**
   * Gets the maximum length of the field value.
   * @type {number|null}
   * @readonly
   */
  get maxLength() {
    return this.rules?.length?.max ?? null;
  }

  /**
   * Validates the field value.
   * @param {string} name - The name of the field.
   * @param {any} value - The value of the field.
   * @param {Object} data - Additional data for validation.
   * @returns {Promise<Object>} The validation errors.
   */
  async validate(name, value, data) {
    if (this.disabled) {
      return { [name]: [] };
    }

    const validator = new Validator(value, this.rules);
    await this.customValidate?.(name, value, data, validator.addError);
    await validator.validate();

    return {
      [name]: validator.errors,
    };
  }
}
