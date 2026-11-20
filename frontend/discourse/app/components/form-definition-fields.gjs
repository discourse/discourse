import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import { settingDefinitionFor } from "discourse/lib/form-definition";

export default class FormDefinitionFields extends Component {
  @cached
  get definitions() {
    return this.args.fields.map(settingDefinitionFor);
  }

  <template>
    {{#each this.definitions key="key" as |definition|}}
      <SettingDefinitionField
        @definition={{definition}}
        @form={{@form}}
        @format="full"
      />
    {{/each}}
  </template>
}
