import Component from "@glimmer/component";
import { action } from "@ember/object";
import ValidationParser from "discourse/form-kit/lib/validation-parser";
import Validator from "discourse/form-kit/lib/validator";
import uniqueId from "discourse/helpers/unique-id";

/**
 * Represents a field in a form with validation, registration, and field data management capabilities.
 */
export default class FKFieldData extends Component {
  /**
   * Unique identifier for the field.
   * @type {string}
   */
  id = uniqueId();

  /**
   * Unique identifier for the field's error element.
   * @type {string}
   */
  errorId = uniqueId();

  /**
   * Type of the field.
   * @type {string}
   */
  type;

  /**
   * Initializes the FKFieldData component.
   * Validates the presence of required arguments and registers the field.
   * @throws {Error} If `@title` is not provided.
   */
  constructor() {
    super(...arguments);

    if (!this.args.title?.length) {
      throw new Error("@title is required on `<form.Field />`.");
    }

    this.args.registerField(this.name, this);
  }

  /**
   * Retrieves the current value of the field.
   * @type {any}
   */
  get value() {
    return this.args.data.get(this.name);
  }

  /**
   * Parses the validation rules for the field.
   * @type {Object|null}
   */
  get rules() {
    return this.args.validation
      ? ValidationParser.parse(this.args.validation)
      : null;
  }

  /**
   * Updates the value of the field and triggers revalidation.
   * @param {any} value - The new value for the field.
   * @returns {Promise<void>}
   */
  @action
  async set(value) {
    if (this.args.onSet) {
      await this.args.onSet(value, {
        set: this.args.set,
        index: this.args.collectionIndex,
      });
    } else {
      await this.args.set(this.name, value, {
        index: this.args.collectionIndex,
      });
    }

    this.args.triggerRevalidationFor(this.name);
  }

  /**
   * Title of the field.
   * @type {string}
   */
  get title() {
    return this.args.title;
  }

  /**
   * Format of the field.
   * @type {string}
   */
  get format() {
    return this.args.format;
  }

  /**
   * Indicates whether the field is disabled.
   * Defaults to `false`.
   * @type {boolean}
   */
  get disabled() {
    return this.args.disabled ?? false;
  }

  /**
   * Description of the field.
   * @type {string}
   */
  get description() {
    return this.args.description;
  }

  /**
   * Help text of the field.
   * @type {string}
   */
  get helpText() {
    return this.args.helpText;
  }

  /**
   * Indicates whether to show the field's title.
   * Defaults to `true`.
   * @type {boolean}
   */
  get showTitle() {
    return this.args.showTitle ?? true;
  }

  /**
   * Function to add errors to the field.
   * @type {Function}
   */
  get addError() {
    return this.args.addError;
  }

  /**
   * Constructs the unique name for the field.
   * @type {string}
   * @throws {Error} If `name` is not a string or contains invalid characters.
   */
  get name() {
    if (typeof this.args.name !== "string") {
      throw new Error(
        "@name is required and must be a string on `<form.Field />`."
      );
    }

    if (this.args.name.includes(".") || this.args.name.includes("-")) {
      throw new Error("@name can't include `.` or `-`.");
    }

    if (this.args.parentName) {
      return `${this.args.parentName}.${this.args.name}`;
    }

    return this.args.name;
  }

  /**
   * Validation rules for the field.
   * @type {string|Object}
   */
  get validation() {
    return this.args.validation;
  }

  /**
   * Custom validation function.
   * @type {Function}
   */
  get customValidate() {
    return this.args.validate;
  }

  /**
   * Indicates if the field is required.
   * Derived from validation rules.
   * @type {boolean}
   * @readonly
   */
  get required() {
    return this.rules?.required ?? false;
  }

  /**
   * Maximum length of the field value.
   * Derived from validation rules.
   * @type {number|null}
   * @readonly
   */
  get maxLength() {
    return this.rules?.length?.max ?? null;
  }

  /**
   * Minimum length of the field value.
   * Derived from validation rules.
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
      if (this.args.collectionIndex !== undefined) {
        title += ` #${this.args.collectionIndex + 1}`;
      }

      this.addError(name, { title, message });
    });
  }

  <template>
    {{yield this}}
  </template>
}
