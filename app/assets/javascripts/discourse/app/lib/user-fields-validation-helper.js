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
  owner;
  field;

  constructor(owner, field) {
    this.owner = owner;
    this.field = field;
  }

  get validation() {
    let validation = validResult();
    if (this.field.required && (!this.value || isEmpty(this.value))) {
      const reasonKey =
        this.field.field_type === "confirm"
          ? "user_fields.required_checkbox"
          : "user_fields.required";
      validation = failedResult({
        reason: i18n(reasonKey, {
          name: this.field.name,
        }),
        element: this.field.element,
      });
    } else if (
      this.owner.accountPassword &&
      this.field.field_type === "text" &&
      this.value &&
      this.value
        .toLowerCase()
        .includes(this.owner.accountPassword.toLowerCase())
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

  get failed() {
    return !!this.validation.failed;
  }

  get ok() {
    return !!this.validation.ok;
  }

  get reason() {
    return this.validation.reason || null;
  }

  get element() {
    return this.validation.element || null;
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
        userFields
          .sortBy("position")
          .map((f) => new TrackedUserField(this.owner, f))
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
