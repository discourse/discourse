import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import FileSizeInput from "admin/components/file-size-input";
import SettingValidationMessage from "admin/components/setting-validation-message";
import { htmlSafe } from "@ember/template";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class FileSizeRestriction extends Component {
  @tracked _validationMessage;

  constructor() {
    super(...arguments);

    this._validationMessage = this.args.validationMessage;
  }

  @action
  updateValidationMessage(message) {
    this._validationMessage = message;
  }

  get validationMessage() {
    return this._validationMessage ?? this.args.validationMessage;
  }

  <template>
    <FileSizeInput
      @sizeValueKB={{this.args.value}}
      @onChangeSize={{fn (mut @value)}}
      @updateValidationMessage={{this.updateValidationMessage}}
      @min={{if this.args.setting.min this.args.setting.min null}}
      @max={{if this.args.setting.max this.args.setting.max null}}
      @message={{this.validationMessage}}
    />

    <SettingValidationMessage @message={{this.validationMessage}} />
    <div class="desc">{{htmlSafe this.args.setting.description}}</div>
  </template>
