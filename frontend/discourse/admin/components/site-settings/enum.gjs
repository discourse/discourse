import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import SelectEnum from "discourse/components/setting-field/-internals/select-enum";
import ComboBox from "discourse/select-kit/components/combo-box";

/**
 * A setting's valid values as `{ value, name }` choices. A bare blank value is the setting's way
 * of allowing none, so it becomes the none option rather than a choice.
 */
export function enumChoices(validValues) {
  return (validValues ?? [])
    .filter((choice) => choice !== "" && choice != null)
    .map((choice) =>
      typeof choice === "object"
        ? { value: choice.value, name: choice.name }
        : { value: choice, name: String(choice) }
    );
}

/**
 * Whether a setting's picker offers a clear button: its default is blank, so the server takes a
 * blank value, and blank isn't already a choice or offered through a none option.
 */
export function enumClearable(setting, choices) {
  return (
    setting.default === "" &&
    !setting.allowsNone &&
    !choices.some((choice) => String(choice.value) === "")
  );
}

export default class Enum extends Component {
  @service siteSettings;

  get choices() {
    return enumChoices(this.args.setting.validValues);
  }

  get clearable() {
    return enumClearable(this.args.setting, this.choices);
  }

  get offersNone() {
    return Boolean(this.args.setting.allowsNone);
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <SelectEnum
          @ariaLabel={{@label}}
          @choices={{this.choices}}
          @clearable={{this.clearable}}
          @disabled={{@disabled}}
          @offersNone={{this.offersNone}}
          @onChange={{@changeValueCallback}}
          @value={{@value}}
        />
      {{else}}
        <ComboBox
          @content={{@setting.validValues}}
          @nameProperty={{@setting.computedNameProperty}}
          @onChange={{@changeValueCallback}}
          @options={{hash
            castInteger=true
            allowAny=@setting.allowsNone
            disabled=@disabled
          }}
          @value={{@value}}
          @valueProperty={{@setting.computedValueProperty}}
        />
      {{/if}}

      {{@preview}}
    </div>
  </template>
}
