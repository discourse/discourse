import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SelectStringList from "discourse/components/setting-field/-internals/select-string-list";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import ListSetting from "discourse/select-kit/components/list-setting";

/**
 * Site setting component for compact list type settings.
 * Supports both static choices and dynamic enum-based validValues.
 *
 * @component CompactList
 * @param {Object} setting - The site setting object
 * @param {string} value - Current setting value (pipe-separated)
 * @param {Function} changeValueCallback - Callback when value changes
 * @param {boolean} allowAny - Whether to allow arbitrary values
 */
export default class CompactList extends Component {
  @service siteSettings;

  /** @type {Array<string | { name: string, value: string }> | null} */
  @tracked createdChoices = null;
  tokenSeparator = "|";

  /**
   * @returns {boolean} Whether the setting has valid values from an enum class
   */
  get hasValidValues() {
    return this.args.setting.validValues?.length > 0;
  }

  /**
   * Whether the values are colours, drawn as squares. A setting can't say so itself yet, so its
   * name decides, as it did for select-kit.
   */
  get isColorList() {
    return Boolean(this.args.setting.setting?.includes("color"));
  }

  /** The setting's own choices: an enum's `{ name, value }` pairs, or its plain choices. */
  get ownChoices() {
    if (this.hasValidValues) {
      return this.args.setting.validValues.map((v) => ({
        name: v.name,
        value: String(v.value),
      }));
    }

    return makeArray(this.args.setting.choices);
  }

  /**
   * @returns {string[]} Current setting value split into array
   */
  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  /**
   * Returns choices for the list setting. When validValues from an enum class
   * are available, uses those (converting values to strings for consistent
   * comparison). Otherwise falls back to static choices.
   *
   * @returns {Array<{name: string, value: string}|string>} Choices for the list
   */
  get settingChoices() {
    if (this.hasValidValues) {
      return this.args.setting.validValues.map((v) => ({
        name: v.name,
        value: String(v.value),
      }));
    }

    return uniqueItemsFromArray([
      ...makeArray(this.settingValue),
      ...makeArray(this.args.setting.choices),
      ...makeArray(this.createdChoices),
    ]);
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  @action
  onChangeChoices(choices) {
    this.createdChoices = uniqueItemsFromArray([
      ...makeArray(this.createdChoices),
      ...makeArray(choices),
    ]);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <SelectStringList
        @allowAny={{@allowAny}}
        @ariaLabel={{@label}}
        @choices={{this.ownChoices}}
        @colors={{this.isColorList}}
        @disabled={{@disabled}}
        @mandatory={{@setting.mandatory_values}}
        @onChange={{this.onChangeListSetting}}
        @values={{this.settingValue}}
      />
    {{else}}
      <ListSetting
        @choices={{this.settingChoices}}
        @mandatoryValues={{@setting.mandatory_values}}
        @nameProperty={{if this.hasValidValues "name"}}
        @onChange={{this.onChangeListSetting}}
        @onChangeChoices={{this.onChangeChoices}}
        @options={{hash allowAny=@allowAny}}
        @settingName={{@setting.setting}}
        @value={{this.settingValue}}
        @valueProperty={{if this.hasValidValues "value"}}
      />
    {{/if}}
  </template>
}
