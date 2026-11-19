import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SelectStringList from "discourse/components/setting-field/-internals/select-string-list";
import { makeArray } from "discourse/lib/helpers";
import ListSetting from "discourse/select-kit/components/list-setting";

/** Site setting component for named list settings: `{ name, value }` choices, stored by value. */
export default class NamedList extends Component {
  @service siteSettings;

  tokenSeparator = "|";

  /**
   * Whether the values are colours, drawn as squares. A setting can't say so itself yet, so its
   * name decides, as it did for select-kit.
   */
  get isColorList() {
    return Boolean(this.args.setting.setting?.includes("color"));
  }

  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  get settingChoices() {
    let choices = this.args.setting.choices;

    if (this.settingValue) {
      const valuesSet = new Set(choices.map((choice) => choice.value));

      choices = choices.concat(
        this.settingValue
          .filter((value) => !valuesSet.has(value))
          .map((value) => ({ name: value, value }))
      );
    }

    return choices;
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <SelectStringList
          @allowAny={{@allowAny}}
          @ariaLabel={{@label}}
          @choices={{makeArray @setting.choices}}
          @colors={{this.isColorList}}
          @disabled={{@disabled}}
          @onChange={{this.onChangeListSetting}}
          @values={{this.settingValue}}
        />
      {{else}}
        <ListSetting
          @choices={{this.settingChoices}}
          @nameProperty="name"
          @onChange={{this.onChangeListSetting}}
          @options={{hash allowAny=@allowAny}}
          @settingName={{@setting.setting}}
          @value={{this.settingValue}}
          @valueProperty="value"
        />
      {{/if}}
    </div>
  </template>
}
