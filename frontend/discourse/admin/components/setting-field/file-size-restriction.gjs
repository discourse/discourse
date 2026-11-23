import Component from "@glimmer/component";
import { action } from "@ember/object";
import FileSizeInput from "discourse/admin/components/file-size-input";
import showFieldError from "discourse/admin/lib/show-field-error";

export default class SettingFieldFileSizeRestriction extends Component {
  #validationMessage;

  @action
  setValidationMessage(message) {
    this.#validationMessage = message;
  }

  @action
  async changeSize(size) {
    this.#validationMessage = this.args.field.error?.messages[0];

    await this.args.field.set(size);

    showFieldError(this.args.field, this.#validationMessage);
  }

  <template>
    <@field.Control>
      <FileSizeInput
        @max={{@definition.max}}
        @min={{@definition.min}}
        @onChangeSize={{this.changeSize}}
        @setValidationMessage={{this.setValidationMessage}}
        @sizeValueKB={{@field.value}}
      />
    </@field.Control>
  </template>
}
