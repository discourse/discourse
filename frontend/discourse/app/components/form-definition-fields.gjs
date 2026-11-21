import SettingDefinitionField from "discourse/components/setting-definition-field";
import FKText from "discourse/form-kit/components/fk/text";
import { settingDefinitionFor } from "discourse/lib/form-definition";

export default <template>
  {{#each @fields key="id" as |field|}}
    {{#if (eq field.type "display_text")}}
      <FKText class="form-definition-fields__text">{{field.content}}</FKText>
    {{else}}
      <SettingDefinitionField
        @definition={{settingDefinitionFor field}}
        @form={{@form}}
        @format="full"
      />
    {{/if}}
  {{/each}}
</template>
