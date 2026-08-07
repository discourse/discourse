import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class SettingFieldEnum extends Component {
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
    <@field.Control
      @includeNone={{this.includeNone}}
      @nonePlaceholder={{if this.includeNone (i18n "admin.settings.none")}}
      as |select|
    >
      {{#if this.hasInvalidSelection}}
        <option value={{this.selectedValue}} selected disabled>
          {{i18n "admin.settings.none"}}
        </option>
      {{/if}}
      {{#each this.choices as |choice|}}
        <select.Option @value={{choice.value}} @selected={{this.selectedValue}}>
          {{choice.name}}
        </select.Option>
      {{/each}}
    </@field.Control>
  </template>
}
