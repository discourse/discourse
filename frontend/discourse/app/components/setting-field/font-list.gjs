import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import FontSelector from "discourse/select-kit/components/font-selector";
import DSelectFont from "discourse/ui-kit/select/recipes/fonts/d-select-font";

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
        <DSelectFont
          @disabled={{@field.disabled}}
          @fonts={{@definition.choices}}
          @onChange={{@field.set}}
          @texts={{hash ariaLabel=@field.title}}
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
