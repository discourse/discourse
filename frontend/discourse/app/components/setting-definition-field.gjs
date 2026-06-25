import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import {
  resolveSettingFieldType,
  settingFieldValidation,
} from "discourse/lib/setting-field-registry";

export default class SettingDefinitionField extends Component {
  @cached
  get entry() {
    return resolveSettingFieldType(this.args.definition);
  }

  get renderer() {
    return this.entry.renderer;
  }

  get description() {
    return this.entry.includeDescription === false
      ? undefined
      : this.args.definition.description;
  }

  get validation() {
    return settingFieldValidation(this.args.definition);
  }

  <template>
    <@form.Field
      @name={{@definition.key}}
      @title={{@definition.label}}
      @description={{this.description}}
      @validation={{this.validation}}
      @type={{this.entry.type}}
      @format={{this.entry.format}}
      @labelFormat={{this.entry.labelFormat}}
      as |field|
    >
      <this.renderer @field={{field}} @definition={{@definition}} />
    </@form.Field>
  </template>
}
