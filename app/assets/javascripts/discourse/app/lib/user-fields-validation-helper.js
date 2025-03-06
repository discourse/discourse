import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { isEmpty } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";

const addCustomUserFieldValidationCallbacks = [];

export function addCustomUserFieldValidationCallback(callback) {
  addCustomUserFieldValidationCallbacks.push(callback);
}

// each userField => EmberObject (converted to TrackedUserField)
//   - field => UserField
//   - value => str
//   - validation => EmberObject
class TrackedUserField {
  @tracked value;
  @tracked validation;
  field;

  constructor(field) {
    this.field = field;
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
      return EmberObject.create({ ok: true });
    }

    this.userFields.forEach((userField) => {
      let validation = EmberObject.create({ ok: true });

      if (
        userField.field.required &&
        (!userField.value || isEmpty(userField.value))
      ) {
        const reasonKey =
          userField.field.field_type === "confirm"
            ? "user_fields.required_checkbox"
            : "user_fields.required";
        validation = EmberObject.create({
          failed: true,
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
        validation = EmberObject.create({
          failed: true,
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

      userField.validation = validation;
    });

    const invalidUserField = this.userFields.find((f) => f.validation.failed);
    if (invalidUserField) {
      return invalidUserField.validation;
    }

    return EmberObject.create({ ok: true });
  }
}
