import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SelectStringList from "discourse/components/setting-field/-internals/select-string-list";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import ListSetting from "discourse/select-kit/components/list-setting";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldCompactList extends Component {
  @service siteSettings;

  /** @type {Array<string | { name: string, value: string }> | null} */
  @tracked createdChoices = null;

  get hasEnumChoices() {
    return this.args.definition.valid_values?.length > 0;
  }

  get allowAny() {
    return this.args.definition.allow_any !== false;
  }

  get settingValue() {
    return (this.args.field.value ?? "")
      .toString()
      .split(TOKEN_SEPARATOR)
      .filter(Boolean);
  }

  /**
   * Whether the values are colours, drawn as squares. A setting can't say so itself yet, so its
   * name decides, as it did for select-kit.
   */
  get isColorList() {
    return Boolean(this.args.definition.key?.includes("color"));
  }

  /** The setting's own choices: an enum's `{ name, value }` pairs, or its plain choices. */
  get ownChoices() {
    if (this.hasEnumChoices) {
      return this.args.definition.valid_values.map((v) => ({
        name: v.name,
        value: String(v.value),
      }));
    }

    return makeArray(this.args.definition.choices);
  }

  get choices() {
    if (this.hasEnumChoices) {
      return this.ownChoices;
    }

    return uniqueItemsFromArray([
      ...this.settingValue,
      ...makeArray(this.args.definition.choices),
      ...makeArray(this.createdChoices),
    ]);
  }

  @action
  onChange(values) {
    this.args.field.set(makeArray(values).join(TOKEN_SEPARATOR));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = uniqueItemsFromArray([
      ...makeArray(this.createdChoices),
      ...makeArray(choices),
    ]);
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <SelectStringList
          @allowAny={{this.allowAny}}
          @ariaLabel={{@field.title}}
          @choices={{this.ownChoices}}
          @colors={{this.isColorList}}
          @disabled={{@field.disabled}}
          @mandatory={{@definition.mandatory_values}}
          @onChange={{this.onChange}}
          @values={{this.settingValue}}
        />
      {{else}}
        <ListSetting
          @choices={{this.choices}}
          @mandatoryValues={{@definition.mandatory_values}}
          @nameProperty={{if this.hasEnumChoices "name"}}
          @onChange={{this.onChange}}
          @onChangeChoices={{this.onChangeChoices}}
          @options={{hash allowAny=this.allowAny disabled=@field.disabled}}
          @settingName={{@definition.key}}
          @value={{this.settingValue}}
          @valueProperty={{if this.hasEnumChoices "value"}}
        />
      {{/if}}
    </@field.Control>
  </template>
}
