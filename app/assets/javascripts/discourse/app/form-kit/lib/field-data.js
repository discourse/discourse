import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import ValidationParser from "discourse/form-kit/lib/validation-parser";
import Validator from "discourse/form-kit/lib/validator";
import uniqueId from "discourse/helpers/unique-id";

/**
 * Represents field data for a form.
 */
export default class FieldData {
  @tracked errors = new TrackedArray();

  /**
   * Unique identifier for the field.
   * @type {string}
   */
  id = uniqueId();

  /**
   * Unique identifier for the field error.
   * @type {Function}
   */
  errorId = uniqueId();

  /**
   * Type of the field.
   * @type {string}
   */
  type;

  /**
   * Creates an instance of FieldData.
   * @param {string} name - The name of the field.
   * @param {Object} options - The options for the field.
   * @param {Function} options.set - The callback function for setting the field value.
   * @param {Function} options.onSet - The callback function for setting the custom field value.
   * @param {string} options.validation - The validation rules for the field.
   * @param {boolean} [options.disabled=false] - Indicates if the field is disabled.
   * @param {Function} [options.validate] - The custom validation function.
   * @param {Function} [options.title] - The custom field title.
   * @param {Function} [options.showTitle=true] - Indicates if the field title should be shown.
   * @param {Function} [options.triggerRevalidationFor] - The function to trigger revalidation.
   * @param {Function} [options.addError] - The function to add an error message.
   */
  constructor(
    name,
    {
      set,
      onSet,
      validation,
      disabled = false,
      validate,
      title,
      showTitle = true,
      triggerRevalidationFor,
      addError,
    }
  ) {
    this.name = name;
    this.title = title;
    this.addError = addError;
    this.showTitle = showTitle;
    this.disabled = disabled;
    this.customValidate = validate;
    this.validation = validation;
    this.rules = this.validation ? ValidationParser.parse(validation) : null;
    this.set = (value) => {
      if (onSet) {
        onSet(value, { set });
      } else {
        set(this.name, value);
      }

      if (this.hasErrors) {
        triggerRevalidationFor(name);
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
    this.reset();

    if (this.disabled) {
      return;
    }

    const validator = new Validator(value, this.rules);

    await this.customValidate?.(name, value, {
      data,
      type: this.type,
      addError: this.addError,
    });

    const validationErrors = await validator.validate(this.type);
    validationErrors.forEach((message) => {
      this.pushError(message);
    });
  }

  /**
   * Adds an error message to the field.
   * @param {string} message - The error message.
   */
  pushError(message) {
    this.errors.push(message);
  }

  /**
   * Checks if the field has any errors.
   * @type {boolean}
   * @readonly
   */
  get hasErrors() {
    return this.errors.length > 0;
  }

  /**
   * Resets the errors for the field.
   */
  reset() {
    this.errors = new TrackedArray();
  }
}
