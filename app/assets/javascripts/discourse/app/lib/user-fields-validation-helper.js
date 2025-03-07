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
  @tracked failed = false;
  @tracked reason = null;
  @tracked element = null;
  field;

  constructor(field) {
    this.field = field;
  }

  get validation() {
    return {
      failed: this.failed,
      reason: this.reason,
      ok: !this.failed,
      element: this.element,
    };
  }

  // Update validation state
  updateValidation(validation = {}) {
    this.failed = !!validation.failed;
    this.reason = validation.reason || null;
    this.element = validation.element || null;
  }
}

export default class UserFieldsValidationHelper {
  @tracked userFields = new TrackedArray();

  constructor(owner) {
    this.owner = owner;
    this.initializeUserFields();
  }

  initializeUserFields() {
    if (!this.owner.site) {
      return;
    }

    let userFields = this.owner.site.get("user_fields");
    if (userFields) {
      this.userFields = new TrackedArray(
        userFields.sortBy("position").map((f) => new TrackedUserField(f))
      );
    }
  }

  get userFieldsValidation() {
    if (!this.userFields) {
      return validResult();
    }

    this.userFields.forEach((userField) => {
      let validation = validResult();

      if (
        userField.field.required &&
        (!userField.value || isEmpty(userField.value))
      ) {
        const reasonKey =
          userField.field.field_type === "confirm"
            ? "user_fields.required_checkbox"
            : "user_fields.required";
        validation = failedResult({
          reason: i18n(reasonKey, {
            name: userField.field.name,
          }),
          element: userField.field.element,
        });
      } else if (
        this.owner.accountPassword &&
        userField.field.field_type === "text" &&
        userField.value &&
        userField.value
          .toLowerCase()
          .includes(this.owner.accountPassword.toLowerCase())
      ) {
        validation = failedResult({
          reason: i18n("user_fields.same_as_password"),
          element: userField.field.element,
        });
      }

      addCustomUserFieldValidationCallbacks.forEach((callback) => {
        const customUserFieldValidationObject = callback(userField);
        if (customUserFieldValidationObject) {
          validation = customUserFieldValidationObject;
        }
      });

      userField.updateValidation(validation);
    });

    const invalidUserField = this.userFields.find((f) => f.validation.failed);
    if (invalidUserField) {
      return invalidUserField.validation;
    }

    return { ok: true };
  }
}
