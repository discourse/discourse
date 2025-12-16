import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
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
  @tracked createdChoices = null;
  tokenSeparator = "|";

  /**
   * @returns {boolean} Whether the setting has valid values from an enum class
   */
  get hasValidValues() {
    return this.args.setting.validValues?.length > 0;
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
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{@setting.setting}}
      @choices={{this.settingChoices}}
      @nameProperty={{if this.hasValidValues "name"}}
      @valueProperty={{if this.hasValidValues "value"}}
      @onChange={{this.onChangeListSetting}}
      @onChangeChoices={{this.onChangeChoices}}
      @options={{hash allowAny=@allowAny}}
      @mandatoryValues={{@setting.mandatory_values}}
    />
  </template>
}
