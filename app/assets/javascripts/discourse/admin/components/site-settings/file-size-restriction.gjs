import Component from "@glimmer/component";
import { action } from "@ember/object";
import FileSizeInput from "admin/components/file-size-input";

export default class FileSizeRestriction extends Component {
  @action
  changeSize(newValue) {
    // Settings are stored as strings, this way the main site setting component
    // doesn't get confused and think the value has changed from default if the
    // admin sets it to the same number as the default.
    this.args.changeValueCallback(newValue?.toString() ?? "");
  }

  <template>
    <FileSizeInput
      @sizeValueKB={{@value}}
      @onChangeSize={{this.changeSize}}
      @max={{@setting.max}}
      @min={{@setting.min}}
      @setValidationMessage={{@setValidationMessage}}
    />
  </template>
}
