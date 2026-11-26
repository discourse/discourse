import Component from "@glimmer/component";
import { action } from "@ember/object";
import FileSizeInput from "discourse/admin/components/file-size-input";
import showFieldError from "discourse/admin/lib/show-field-error";

export default class SettingFieldFileSizeRestriction extends Component {
  @action
  async changeSize(size, validationMessage) {
    await this.args.field.set(size);

    showFieldError(this.args.field, validationMessage);
  }

  <template>
    <@field.Control>
      <FileSizeInput
        @max={{@definition.max}}
        @min={{@definition.min}}
        @onChangeSize={{this.changeSize}}
        @sizeValueKB={{@field.value}}
      />
    </@field.Control>
  </template>
}
