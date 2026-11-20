/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import { tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import withEventValue from "discourse/helpers/with-event-value";
import {
  addUniqueValueToArray,
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DSelect from "discourse/ui-kit/select/d-select";
import { renderSelectText } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const INDEX_KEY = "@index";

/** Whether a list was given anything at all. */
function hasItems(list) {
  return makeArray(list).length > 0;
}

/** A value as the add field's record. */
function valueRecord(value) {
  const name = String(value).trim();
  return { id: name, name };
}

/**
 * Renders its rows through the shared reorderable list when
 * `enable_new_reordering_controls` is on, and through the legacy rows
 * otherwise. The branch lives here so every caller follows the change.
 *
 * TODO (ui-kit-reorderable-list-cleanup) delete the legacy arm and the
 * members marked for it once the change ships.
 */
@classNames("value-list")
export default class ValueList extends Component {
  @service siteSettings;

  /** @type {string[] | null} */
  @autoTrackedArray collection = null;

  /** Whether the add field takes typed values, not just the offered choices. */
  allowAny = true;

  /** @type {string | null} */
  inputDelimiter = null;

  /** @type {"array" | null} */
  inputType = null;
  newValue = "";

  /** @type {string | string[] | null | undefined} */
  values = null;

  /** @type {((values: string[]) => void | Promise<void>) | null} */
  onChange = null;

  valueLabel = (value) => value;

  @tracked _noneKeyOverride;

  @computed("addKey")
  get noneKey() {
    if (this._noneKeyOverride !== undefined) {
      return this._noneKeyOverride;
    }
    return this.addKey;
  }

  set noneKey(value) {
    this._noneKeyOverride = value;
  }

  @computed("newValue", "inputDelimiter")
  get inputInvalid() {
    return (
      isEmpty(this.newValue) ||
      this.newValue.includes(this.inputDelimiter || "\n")
    );
  }

  @computed("choices.[]", "collection.[]")
  get filteredChoices() {
    return makeArray(this.choices).filter((i) => !this.collection?.includes(i));
  }

  /** The choices the list doesn't hold, as the add field's records. A list never holds a blank value. */
  @computed("filteredChoices")
  get addOptions() {
    return this.filteredChoices
      .filter((choice) => String(choice).trim())
      .map(valueRecord);
  }

  /** The add field's prompt, which also names it. */
  @computed("noneKey")
  get addPrompt() {
    return i18n(this.noneKey || "admin.site_settings.simple_list.add_item");
  }

  @computed("addPrompt")
  get addTexts() {
    return { ariaLabel: this.addPrompt, placeholder: this.addPrompt };
  }

  /** A list that takes only its choices has no add field once it holds them all. */
  @computed("allowAny", "addOptions")
  get canAdd() {
    return this.allowAny || this.addOptions.length > 0;
  }

  // TODO (ui-kit-reorderable-list-cleanup) delete with the legacy arm below.
  @computed("collection")
  get showUpDownButtons() {
    return this.collection.length - 1 ? true : false;
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.inputType === "array") {
      this.set("collection", this.values ? [...this.values] : []);
      return;
    }

    this.set(
      "collection",
      this._splitValues(this.values, this.inputDelimiter || "\n")
    );
  }

  keyDown(event) {
    if (event.key === "Enter") {
      this.send("addValue", this.newValue);
    }
  }

  @action
  changeValue(index, event) {
    this._replaceValue(index, event.target.value);
  }

  @action
  addValue(newValue) {
    if (this.inputInvalid) {
      return;
    }

    this.set("newValue", null);
    this._addValue(newValue);
  }

  @action
  removeValue(value) {
    this._removeValue(value);
  }

  @action
  selectChoice(choice) {
    this._addValue(choice);
  }

  /** A typed value is taken only when any is allowed, and never with the list's delimiter in it. */
  @action
  allowCreate(value) {
    return this.allowAny && !this.holdsDelimiter(value);
  }

  @action
  holdsDelimiter(value) {
    return value.includes(this.inputDelimiter || "\n");
  }

  /** Enter in the text field adds its value (see `keyDown`), so it must not also submit a form. */
  @action
  keepEnterInField(event) {
    if (event.key === "Enter") {
      event.preventDefault();
    }
  }

  /**
   * Applies a committed move onto the collection and persists the new order.
   * Wrapping and announcements are the list's own.
   *
   * @param {import("discourse/ui-kit/d-reorderable-list/types").ReorderableMove<string>} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.collection.splice(0, this.collection.length, ...move.proposedToItems);
    this._saveValues();
  }

  // TODO (ui-kit-reorderable-list-cleanup) delete with the legacy arm below.
  @action
  shift(operation, index) {
    let futureIndex = index + operation;

    if (futureIndex > this.collection.length - 1) {
      futureIndex = 0;
    } else if (futureIndex < 0) {
      futureIndex = this.collection.length - 1;
    }

    const shiftedValue = this.collection[index];
    this.collection.splice(index, 1);
    this.collection.splice(futureIndex, 0, shiftedValue);

    this._saveValues();
  }

  _addValue(value) {
    addUniqueValueToArray(this.collection, value);

    if (this.choices) {
      this.set(
        "choices",
        this.choices.filter((choice) => choice.id !== value)
      );
    } else {
      this.set("choices", []);
    }

    this._saveValues();
  }

  _removeValue(value) {
    removeValueFromArray(this.collection, value);

    if (this.choices) {
      this.set("choices", uniqueItemsFromArray(this.choices.concat([value])));
    } else {
      this.set("choices", makeArray(value));
    }

    this._saveValues();
  }

  _replaceValue(index, newValue) {
    this.collection.splice(index, 1, newValue);
    this._saveValues();
  }

  _saveValues() {
    if (this.onChange) {
      this.onChange([...this.collection]);
      return;
    }

    if (this.inputType === "array") {
      this.set("values", this.collection);
      return;
    }

    this.set("values", this.collection.join(this.inputDelimiter || "\n"));
  }

  _splitValues(values, delimiter) {
    if (values && values.length) {
      return values.split(delimiter).filter((x) => x);
    } else {
      return [];
    }
  }

  <template>
    {{#if this.collection}}
      {{#if this.siteSettings.enable_new_reordering_controls}}
        <DReorderableList
          class="values"
          @items={{this.collection}}
          @itemTag="div"
          @key={{INDEX_KEY}}
          @label={{this.valueLabel}}
          @onMove={{this.handleMove}}
          @onRemove={{this.removeValue}}
          @rowClass="value"
          @tag="div"
        >
          <:row as |value controls|>
            <Input
              class="value-input"
              title={{value}}
              @value={{value}}
              {{on "focusout" (fn this.changeValue controls.index)}}
            />
          </:row>
        </DReorderableList>
      {{else}}
        <div class="values">
          {{#each this.collection as |value index|}}
            <div class="value" data-index={{index}}>
              <DButton
                class="btn-default remove-value-btn btn-small"
                @action={{fn this.removeValue value}}
                @icon="xmark"
              />

              <Input
                class="value-input"
                title={{value}}
                @value={{value}}
                {{on "focusout" (fn this.changeValue index)}}
              />

              {{#if this.showUpDownButtons}}
                <DButton
                  class="btn-default shift-up-value-btn btn-small"
                  @action={{fn this.shift -1 index}}
                  @icon="arrow-up"
                />
                <DButton
                  class="btn-default shift-down-value-btn btn-small"
                  @action={{fn this.shift 1 index}}
                  @icon="arrow-down"
                />
              {{/if}}
            </div>
          {{/each}}
        </div>
      {{/if}}
    {{/if}}

    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      {{! The original choices decide the field, so adding the last one doesn't swap it under the user. }}
      {{#if (hasItems @choices)}}
        {{#if this.canAdd}}
          <DSelect
            @allowCreate={{this.allowCreate}}
            @createOption={{valueRecord}}
            @disabled={{@disabled}}
            @onChange={{this.selectChoice}}
            @options={{this.addOptions}}
            @texts={{this.addTexts}}
            @value={{null}}
          >
            <:empty as |state config|>
              {{#if state.query}}
                {{#if (this.holdsDelimiter state.query)}}
                  {{i18n "admin.site_settings.compact_list.not_allowed"}}
                {{else if this.allowAny}}
                  {{renderSelectText config "noResults"}}
                {{else}}
                  {{i18n
                    "admin.site_settings.value_list.not_a_choice"
                    value=state.query
                  }}
                {{/if}}
              {{else}}
                {{i18n "admin.site_settings.compact_list.placeholder"}}
              {{/if}}
            </:empty>
          </DSelect>
        {{/if}}
      {{else}}
        <div class="simple-list-input">
          <input
            aria-label={{this.addPrompt}}
            autocapitalize="off"
            autocomplete="off"
            autocorrect="off"
            class="add-value-input"
            disabled={{@disabled}}
            placeholder={{this.addPrompt}}
            type="text"
            value={{this.newValue}}
            {{on "input" (withEventValue (fn (mut this.newValue)))}}
            {{on "keydown" this.keepEnterInField}}
          />
          <DButton
            class="add-value-btn btn-default btn-small"
            @action={{fn this.addValue this.newValue}}
            @disabled={{or @disabled this.inputInvalid}}
            @icon="plus"
          />
        </div>
      {{/if}}
    {{else}}
      <ComboBox
        @content={{this.filteredChoices}}
        @nameProperty={{null}}
        @onChange={{this.selectChoice}}
        @options={{hash allowAny=true none=this.noneKey disabled=@disabled}}
        @value={{this.newValue}}
        @valueProperty={{null}}
      />
    {{/if}}
  </template>
}
