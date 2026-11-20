import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  enumChoices,
  enumClearable,
} from "discourse/admin/components/site-settings/enum";
import SelectEnum from "discourse/components/setting-field/-internals/select-enum";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class LocaleEnum extends Component {
  @service languageNameLookup;
  @service siteSettings;

  get choices() {
    return enumChoices(this.args.setting.validValues).map(({ value }) => ({
      value,
      name: this.languageNameLookup.getLanguageName(value),
    }));
  }

  get clearable() {
    return enumClearable(this.args.setting, this.choices);
  }

  get offersNone() {
    return Boolean(this.args.setting.allowsNone);
  }

  get content() {
    return this.args.setting.validValues.map(({ value }) => ({
      name: this.languageNameLookup.getLanguageName(value),
      value,
    }));
  }

  @action
  onChangeLocale(value) {
    this.args.changeValueCallback(value);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <SelectEnum
        @ariaLabel={{@label}}
        @choices={{this.choices}}
        @clearable={{this.clearable}}
        @disabled={{@disabled}}
        @offersNone={{this.offersNone}}
        @onChange={{this.onChangeLocale}}
        @value={{@value}}
      />
    {{else}}
      <ComboBox
        @content={{this.content}}
        @nameProperty={{@setting.computedNameProperty}}
        @onChange={{this.onChangeLocale}}
        @options={{hash castInteger=true allowAny=@setting.allowsNone}}
        @value={{@value}}
        @valueProperty={{@setting.computedValueProperty}}
      />
    {{/if}}

    {{@preview}}
  </template>
}
