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
    return this.args.format ?? this.args.definition.format ?? this.entry.format;
  }

  get validation() {
    return settingFieldValidation(this.args.definition);
  }

  <template>
    <@form.Field
      @description={{this.description}}
      @disabled={{@disabled}}
      @format={{this.format}}
      @labelFormat={{this.entry.labelFormat}}
      @name={{@definition.key}}
      @placeholder={{@definition.placeholder}}
      @showControlTitle={{@showControlTitle}}
      @showTitle={{@showTitle}}
      @title={{@definition.label}}
      @type={{this.entry.type}}
      @validation={{this.validation}}
      as |field|
    >
      {{#if this.renderer}}
        <this.renderer @definition={{@definition}} @field={{field}} />
      {{else}}
        <field.Control placeholder={{field.placeholder}} />
      {{/if}}
    </@form.Field>
  </template>
}
