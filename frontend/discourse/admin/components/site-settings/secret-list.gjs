import SecretValueList from "discourse/admin/components/secret-value-list";

const SecretList = <template>
  <SecretValueList
    @setting={{@setting}}
    @values={{@value}}
    @isSecret={{@isSecret}}
    @setValidationMessage={{@setValidationMessage}}
    @changeValueCallback={{@changeValueCallback}}
  />
</template>;

export default SecretList;
