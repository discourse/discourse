import Component from "@glimmer/component";
import { service } from "@ember/service";
import SelectFont from "discourse/components/setting-field/-internals/select-font";
import FontSelector from "discourse/select-kit/components/font-selector";

export default class FontList extends Component {
  @service siteSettings;

  get choices() {
    const classPrefix =
      this.args.setting.setting === "heading_font"
        ? "heading-font-"
        : "body-font-";

    return this.args.setting.choices.map((choice) => {
      return {
        classNames: classPrefix + choice.value.replace(/_/g, "-"),
        id: choice.value,
        name: choice.name,
      };
    });
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <SelectFont
        @ariaLabel={{@label}}
        @choices={{@setting.choices}}
        @disabled={{@disabled}}
        @onChange={{@changeValueCallback}}
        @value={{@value}}
      />
    {{else}}
      <FontSelector
        @content={{this.choices}}
        @onChange={{@changeValueCallback}}
        @value={{@value}}
      />
    {{/if}}
  </template>
}
