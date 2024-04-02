import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import I18n from "discourse-i18n";

export default class SchemaThemeSettingTypeModels extends Component {
  @tracked touched = false;
  @tracked value = this.args.value;

  required = this.args.spec.required;
  min = this.args.spec.validations?.min;
  max = this.args.spec.validations?.max;
  type;

  @action
  onInput(newValue) {
    this.touched = true;
    this.value = newValue;
    this.args.onChange(this.onChange(newValue));
  }

  onChange(newValue) {
    return newValue;
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (
      (this.min && this.value.length < this.min) ||
      (this.required && (!this.value || this.value.length === 0))
    ) {
      return I18n.t(
        `admin.customize.theme.schema.fields.${this.type}.at_least`,
        {
          count: this.min || 1,
        }
      );
    }
  }
}
