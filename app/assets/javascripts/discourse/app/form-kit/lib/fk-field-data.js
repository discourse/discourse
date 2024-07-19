import ValidationParser from "discourse/form-kit/lib/validation-parser";
import Validator from "discourse/form-kit/lib/validator";
import uniqueId from "discourse/helpers/unique-id";

/**
 * Represents field data for a form.
 */
export default class FKFieldData {
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
   * @param {Function} [options.subtitle] - The custom field subtitle.
   * @param {Function} [options.description] - The custom field description.
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
      subtitle,
      description,
      showTitle = true,
      triggerRevalidationFor,
      collectionIndex,
      addError,
    }
  ) {
    this.name = name;
    this.title = title;
    this.subtitle = subtitle;
    this.description = description;
    this.collectionIndex = collectionIndex;
    this.addError = addError;
    this.showTitle = showTitle;
    this.disabled = disabled;
    this.customValidate = validate;
    this.validation = validation;
    this.rules = this.validation ? ValidationParser.parse(validation) : null;
    this.set = (value) => {
      if (onSet) {
        onSet(value, { set, index: collectionIndex });
      } else {
        set(this.name, value, { index: collectionIndex });
      }

      triggerRevalidationFor(name);
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
   * Sets the type of the field.
   */
  setType(type) {
    this.type = type;
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
   * Gets the minimum length of the field value.
   * @type {number|null}
   * @readonly
   */
  get minLength() {
    return this.rules?.length?.min ?? null;
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
      return;
    }

    await this.customValidate?.(name, value, {
      data,
      type: this.type,
      addError: this.addError,
    });

    const validator = new Validator(value, this.rules);
    const validationErrors = await validator.validate(this.type);
    validationErrors.forEach((message) => {
      let title = this.title;
      if (this.collectionIndex !== undefined) {
        title += ` #${this.collectionIndex + 1}`;
      }

      this.addError(name, { title, message });
    });
  }
}
