import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import SelectFont from "discourse/components/setting-field/-internals/select-font";
import FontSelector from "discourse/select-kit/components/font-selector";

export default class SettingFieldFontList extends Component {
  @service siteSettings;

  get choices() {
    return this.args.definition.choices.map(({ value, name }) => ({
      classNames: `body-font-${value.replace(/_/g, "-")}`,
      id: value,
      name,
    }));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <SelectFont
          @ariaLabel={{@field.title}}
          @choices={{@definition.choices}}
          @disabled={{@field.disabled}}
          @onChange={{@field.set}}
          @value={{@field.value}}
        />
      {{else}}
        <FontSelector
          @content={{this.choices}}
          @onChange={{@field.set}}
          @options={{hash disabled=@field.disabled}}
          @value={{@field.value}}
        />
      {{/if}}
    </@field.Control>
  </template>
}
