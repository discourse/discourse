import { fn } from "@ember/helper";
import SecretValueList from "discourse/admin/components/secret-value-list";
import showFieldError from "discourse/admin/lib/show-field-error";

const SettingFieldSecretList = <template>
  <@field.Control>
    <SecretValueList
      @changeValueCallback={{@field.set}}
      @isSecret={{@definition.secret}}
      @placeholder={{@definition.placeholder}}
      @setValidationMessage={{fn showFieldError @field}}
      @values={{@field.value}}
    />
  </@field.Control>
</template>;

export default SettingFieldSecretList;
