/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { classNameBindings } from "@ember-decorators/component";

@classNameBindings(":user-field", "field.field_type", "customFieldClass")
export default class UserFieldBase extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    let element = this.element.querySelector(
      ".user-field.dropdown .select-kit-header"
    );
    element = element || this.element.querySelector("input");
    this.field.element = element;
  }

  @computed
  get noneLabel() {
    return "user_fields.none";
  }

  @computed("field.name")
  get customFieldClass() {
    let fieldName = this.field?.name;
    if (fieldName) {
      fieldName = fieldName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return fieldName && `user-field-${fieldName}`;
    }
    return undefined;
  }
}
