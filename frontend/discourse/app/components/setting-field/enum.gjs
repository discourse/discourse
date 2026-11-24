import Component from "@glimmer/component";
import { service } from "@ember/service";
import SelectEnum from "discourse/components/setting-field/-internals/select-enum";
import { i18n } from "discourse-i18n";

export default class SettingFieldEnum extends Component {
  @service siteSettings;

  get rawChoices() {
    return (
      this.args.definition.valid_values ?? this.args.definition.choices ?? []
    );
  }

  get hasBlankChoice() {
    return this.rawChoices.includes("");
  }

  get includeNone() {
    if (this.hasBlankChoice) {
      return true;
    }

    return this.args.definition.allows_none;
  }

  get choices() {
    return this.rawChoices
      .filter((choice) => choice != null && choice !== "")
      .map((choice) =>
        typeof choice === "object"
          ? { value: String(choice.value), name: choice.name }
          : { value: String(choice), name: String(choice) }
      );
  }

  get fallbackChoice() {
    const selected = this.selectedValue;

    if (
      selected === "" ||
      this.choices.some(({ value }) => value === selected)
    ) {
      return null;
    }

    return { value: selected, name: selected };
  }

  /**
   * Whether the picker offers a clear button: the setting's default is blank, so the server takes a
   * blank value, and blank isn't already a choice to pick or offered through a none option.
   */
  get clearable() {
    return (
      this.args.definition.default === "" &&
      !this.offersNone &&
      !this.choices.some((choice) => choice.value === "")
    );
  }

  /** Whether the picker offers a none option; a field that isn't required may be left blank. */
  get offersNone() {
    return this.includeNone ?? !this.args.definition.required;
  }

  get selectedValue() {
    return String(this.args.field.value ?? "");
  }

  get hasInvalidSelection() {
    return (
      this.selectedValue !== "" &&
      !this.choices.some((choice) => choice.value === this.selectedValue)
    );
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the native select branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <@field.Control>
        <SelectEnum
          @ariaLabel={{@field.title}}
          @choices={{this.choices}}
          @clearable={{this.clearable}}
          @disabled={{@field.disabled}}
          @offersNone={{this.offersNone}}
          @onChange={{@field.set}}
          @value={{@field.value}}
        />
      </@field.Control>
    {{else}}
      <@field.Control
        @includeNone={{this.includeNone}}
        @nonePlaceholder={{if this.includeNone (i18n "admin.settings.none")}}
        as |select|
      >
        {{#if this.hasInvalidSelection}}
          <option disabled selected value={{this.selectedValue}}>
            {{i18n "admin.settings.none"}}
          </option>
        {{/if}}
        {{#each this.choices as |choice|}}
          <select.Option @value={{choice.value}}>
            {{choice.name}}
          </select.Option>
        {{/each}}
        {{#if this.fallbackChoice}}
          <select.Option @value={{this.fallbackChoice.value}}>
            {{this.fallbackChoice.name}}
          </select.Option>
        {{/if}}
      </@field.Control>
    {{/if}}
  </template>
}
