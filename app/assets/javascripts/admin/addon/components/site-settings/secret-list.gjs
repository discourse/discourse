import Component from "@ember/component";

export default class SecretList extends Component {}

<SecretValueList
  @setting={{this.setting}}
  @values={{this.value}}
  @isSecret={{this.isSecret}}
  @setValidationMessage={{this.setValidationMessage}}
/>