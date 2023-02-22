import Component from "@glimmer/component";

export default class FormTemplateFieldWrapper extends Component {
  ALLOWED_FIELD_TYPES = [
    "checkbox",
    "dropdown",
    "input",
    "multi-select",
    "textarea",
    "upload",
  ];

  get showField() {
    if (!this.ALLOWED_FIELD_TYPES.includes(this.args.content.type)) {
      return false;
    }
    return true;
  }
}
