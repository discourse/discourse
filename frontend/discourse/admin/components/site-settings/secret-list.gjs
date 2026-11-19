import SecretValueList from "discourse/admin/components/secret-value-list";

const SecretList = <template>
  <SecretValueList
    @changeValueCallback={{@changeValueCallback}}
    @isSecret={{@isSecret}}
    @placeholder={{@setting.placeholder}}
    @setValidationMessage={{@setValidationMessage}}
    @values={{@value}}
  />
</template>;

export default SecretList;
