import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";

/** The key a value is held under: values can be numbers, keys are always strings. */
function keyOf(value) {
  return String(value ?? "");
}

/**
 * Picks an enum setting's value from a typeahead of its `{ value, name }` choices. A held value
 * that is no longer a choice is listed as itself, so it is never replaced unseen. `@offersNone`
 * adds a none option and `@clearable` a clear button, both reporting `null`; any other pick reports
 * the choice's own value, keeping its type.
 */
export default class SelectEnum extends Component {
  /** Each choice's own value by its key, to report a pick in the type the setting stores. */
  get choiceValues() {
    return new Map(
      this.args.choices.map((choice) => [keyOf(choice.value), choice.value])
    );
  }

  /** The held key, or `null` when the setting holds nothing; a blank value can be a choice. */
  get heldKey() {
    const key = keyOf(this.args.value);
    if (key === "" && !this.choiceValues.has("")) {
      return null;
    }
    return key;
  }

  get records() {
    const records = this.args.choices.map((choice) => ({
      id: keyOf(choice.value),
      name: choice.name,
    }));
    const held = this.heldKey;
    if (held !== null && !this.choiceValues.has(held)) {
      records.push({ id: held, name: held });
    }
    return records;
  }

  @action
  onChange(key) {
    if (key === null) {
      this.args.onChange(null);
      return;
    }
    this.args.onChange(
      this.choiceValues.has(key) ? this.choiceValues.get(key) : key
    );
  }

  <template>
    <DSelect
      class="select-enum"
      @clearable={{@clearable}}
      @disabled={{@disabled}}
      @noneOption={{@offersNone}}
      @onChange={{this.onChange}}
      @options={{this.records}}
      @texts={{hash ariaLabel=@ariaLabel}}
      @value={{this.heldKey}}
    />
  </template>
}
