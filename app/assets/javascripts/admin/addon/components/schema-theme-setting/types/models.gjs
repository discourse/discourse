import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import { i18n } from "discourse-i18n";

export default class SchemaThemeSettingTypeModels extends Component {
  @tracked value = this.args.value;

  required = this.args.spec.required;
  min = this.args.spec.validations?.min;
  max = this.args.spec.validations?.max;
  type;

  @action
  onInput(newValue) {
    this.value = newValue;
    this.args.onChange(this.onChange(newValue));
  }

  onChange(newValue) {
    return newValue;
  }

  get validationErrorMessage() {
    const isValueBlank = isBlank(this.value);

    if (!this.required && isValueBlank) {
      return;
    }

    if (
      (this.min && this.value && this.value.length < this.min) ||
      (this.required && isValueBlank)
    ) {
      return i18n(`admin.customize.theme.schema.fields.${this.type}.at_least`, {
        count: this.min || 1,
      });
    }
  }
}
