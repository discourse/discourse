import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import FontSelector from "discourse/select-kit/components/font-selector";
import DSelectFont from "discourse/ui-kit/select/recipes/fonts/d-select-font";

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
      <DSelectFont
        @disabled={{@disabled}}
        @fonts={{@setting.choices}}
        @onChange={{@changeValueCallback}}
        @texts={{hash ariaLabel=@label}}
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
