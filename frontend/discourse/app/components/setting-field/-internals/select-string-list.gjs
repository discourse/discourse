import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import DSelect from "discourse/ui-kit/select/d-select";
import { renderSelectText } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const TOKEN_SEPARATOR = "|";

/** A typed value as the picker's record. */
function typedRecord(value) {
  const name = value.trim();
  return { id: name, name };
}

/** A setting choice as the picker's record: a plain value, or an enum's `{ name, value }`. */
function choiceRecord(choice) {
  if (typeof choice === "string") {
    return { id: choice, name: choice };
  }
  return { id: String(choice.value), name: choice.name };
}

/**
 * Picks a string list setting's values: its choices, plus typed ones when `@allowAny` is set. A
 * value removed from the list stays listed, unticked, and held `@mandatory` values can't be
 * removed. A `:footer` block draws in the open panel, below the list.
 */
export default class SelectStringList extends Component {
  /**
   * Every value the list has held since the picker rendered, in the order each was first held, so
   * a removed one keeps its row and can be picked again.
   */
  @tracked offered = [];

  /** A list with no choices to search, whose texts ask for values instead. */
  get freeText() {
    return Boolean(this.args.allowAny) && !(this.args.choices?.length > 0);
  }

  get lockedValues() {
    const mandatory = (this.args.mandatory ?? "")
      .split(TOKEN_SEPARATOR)
      .filter(Boolean);
    return this.args.values.filter((value) => mandatory.includes(value));
  }

  get options() {
    const records = (this.args.choices ?? []).map(choiceRecord);
    const known = new Set(records.map((record) => record.id));
    for (const value of [...this.offered, ...this.args.values]) {
      if (!known.has(value)) {
        known.add(value);
        records.push({ id: value, name: value });
      }
    }
    return records;
  }

  get texts() {
    if (!this.freeText) {
      return { ariaLabel: this.args.ariaLabel };
    }
    return {
      ariaLabel: this.args.ariaLabel,
      placeholder: i18n("admin.site_settings.compact_list.placeholder"),
      addMorePlaceholder: i18n(
        "admin.site_settings.compact_list.add_more_placeholder"
      ),
    };
  }

  @action
  allowCreate(value) {
    return Boolean(this.args.allowAny) && !value.includes(TOKEN_SEPARATOR);
  }

  @action
  onChange(values) {
    this.offered = uniqueItemsFromArray([
      ...this.offered,
      ...this.args.values,
      ...values,
    ]);
    this.args.onChange(values);
  }

  <template>
    <DSelect
      class="select-string-list"
      @allowCreate={{this.allowCreate}}
      @createOption={{typedRecord}}
      @disabled={{@disabled}}
      @lockedValues={{this.lockedValues}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{this.texts}}
      @value={{@values}}
    >
      <:option as |option config|>
        {{#if option.create}}
          {{renderSelectText config "createOption" (hash label=option.label)}}
        {{else}}
          {{option.label}}
        {{/if}}
      </:option>
      <:empty as |state config|>
        {{#if this.freeText}}
          {{#if state.query}}
            {{i18n "admin.site_settings.compact_list.not_allowed"}}
          {{else}}
            {{i18n "admin.site_settings.compact_list.empty"}}
          {{/if}}
        {{else}}
          {{renderSelectText config "noResults" (hash query=state.query)}}
        {{/if}}
      </:empty>
      <:footer as |state config|>
        {{yield state config to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
