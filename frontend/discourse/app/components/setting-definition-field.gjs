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
    if (
      this.args.showDescription === false ||
      this.entry.includeDescription === false
    ) {
      return undefined;
    }

    return this.args.definition.description;
  }

  get format() {
    return this.args.definition.format ?? this.entry.format;
  }

  get validation() {
    return settingFieldValidation(this.args.definition);
  }

  <template>
    <@form.Field
      @name={{@definition.key}}
      @title={{@definition.label}}
      @showTitle={{@showTitle}}
      @showControlTitle={{@showControlTitle}}
      @description={{this.description}}
      @placeholder={{@definition.placeholder}}
      @validation={{this.validation}}
      @disabled={{@disabled}}
      @type={{this.entry.type}}
      @format={{this.format}}
      @labelFormat={{this.entry.labelFormat}}
      as |field|
    >
      {{#if this.renderer}}
        <this.renderer @field={{field}} @definition={{@definition}} />
      {{else}}
        <field.Control placeholder={{field.placeholder}} />
      {{/if}}
    </@form.Field>
  </template>
}
