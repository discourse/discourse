import Component from "@ember/component";

export default class SettingValidationMessage extends Component {}

<div class="validation-error {{unless this.message 'hidden'}}">
  {{d-icon "xmark"}}
  {{this.message}}
</div>