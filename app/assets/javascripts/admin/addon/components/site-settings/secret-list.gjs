import Component from "@ember/component";
import SecretValueList from "admin/components/secret-value-list";

export default class SecretList extends Component {
  <template>
    <SecretValueList
      @setting={{this.setting}}
      @values={{this.value}}
      @isSecret={{this.isSecret}}
      @setValidationMessage={{this.setValidationMessage}}
    />
  </template>
}
