import { tracked } from "@glimmer/tracking";
import { isEmpty } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";

const addCustomUserFieldValidationCallbacks = [];

export function addCustomUserFieldValidationCallback(callback) {
  addCustomUserFieldValidationCallbacks.push(callback);
}

function failedResult(attrs) {
  return {
    failed: true,
    ok: false,
    ...attrs,
  };
}

function validResult(attrs) {
  return { ok: true, ...attrs };
}

class TrackedUserField {
  @tracked value = null;
  field;
  getValidationVisible;
  getAccountPassword;

  constructor({ field, getValidationVisible, getAccountPassword }) {
    this.field = field;
    this.getValidationVisible = getValidationVisible;
    this.getAccountPassword = getAccountPassword;
  }

  get validation() {
    if (!this.getValidationVisible()) {
      return validResult();
    }

    let validation = validResult();
    if (this.field.required && (!this.value || isEmpty(this.value))) {
      const reasonKey =
        this.field.field_type === "confirm"
          ? "user_fields.required_checkbox"
          : this.field.field_type === "text"
            ? "user_fields.required"
            : "user_fields.required_select";
      validation = failedResult({
        reason: i18n(reasonKey, {
          name: this.field.name,
        }),
        element: this.field.element,
      });
    } else if (
      this.getAccountPassword() &&
      this.field.field_type === "text" &&
      this.value &&
      this.value.toLowerCase().includes(this.getAccountPassword().toLowerCase())
    ) {
      validation = failedResult({
        reason: i18n("user_fields.same_as_password"),
        element: this.field.element,
      });
    }

    addCustomUserFieldValidationCallbacks.forEach((callback) => {
      const customUserFieldValidationObject = callback(this);
      if (customUserFieldValidationObject) {
        validation = customUserFieldValidationObject;
      }
    });

    return validation;
  }
}

export default class UserFieldsValidationHelper {
  @tracked userFields = new TrackedArray();
  @tracked validationVisible = true;

  constructor({
    getUserFields,
    getAccountPassword,
    showValidationOnInit = true,
  }) {
    this.getUserFields = getUserFields;
    this.getAccountPassword = getAccountPassword;
    this.validationVisible = showValidationOnInit;
    this.initializeUserFields();
  }

  initializeUserFields() {
    let userFields = this.getUserFields();
    if (userFields) {
      const getValidationVisible = () => this.validationVisible;
      this.userFields = new TrackedArray(
        userFields.sortBy("position").map((f) => {
          return new TrackedUserField({
            field: f,
            getValidationVisible,
            getAccountPassword: this.getAccountPassword,
          });
        })
      );
    }
  }

  get userFieldsValidation() {
    if (!this.userFields) {
      return validResult();
    }
    const invalidUserField = this.userFields.find((f) => f.validation.failed);
    return invalidUserField ? invalidUserField.validation : validResult();
  }
}
