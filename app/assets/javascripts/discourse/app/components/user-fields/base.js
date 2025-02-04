import Component from "@ember/component";
import { classNameBindings } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

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

  @discourseComputed
  noneLabel() {
    return "user_fields.none";
  }

  @discourseComputed("field.name")
  customFieldClass(fieldName) {
    if (fieldName) {
      fieldName = fieldName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return fieldName && `user-field-${fieldName}`;
    }
  }
}
