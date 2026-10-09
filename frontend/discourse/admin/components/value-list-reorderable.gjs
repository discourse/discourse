/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import { tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import {
  addUniqueValueToArray,
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import { makeArray } from "discourse/lib/helpers";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import ComboBox from "discourse/select-kit/components/combo-box";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

const INDEX_KEY = "@index";

@classNames("value-list")
/**
 * The reordering surface behind `enable_new_reordering_controls`. Mirrors
 * `value-list.gjs`, over the shared reorderable list.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over `value-list.gjs`
 * and drop the branch in the site-settings and user-fields-form call sites.
 */
export default class ValueList extends Component {
  @autoTrackedArray collection = null;

  inputDelimiter = null;
  inputType = null;
  newValue = "";
  values = null;
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

  @computed("newValue")
  get inputInvalid() {
    return isEmpty(this.newValue);
  }

  @computed("choices.[]", "collection.[]")
  get filteredChoices() {
    return makeArray(this.choices).filter((i) => !this.collection?.includes(i));
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

  /**
   * Applies a committed move onto the collection and persists the new order.
   * Wrapping and announcements are the list's own.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.collection.splice(0, this.collection.length, ...move.proposedToItems);
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
    {{/if}}

    <ComboBox
      @content={{this.filteredChoices}}
      @nameProperty={{null}}
      @onChange={{this.selectChoice}}
      @options={{hash allowAny=true none=this.noneKey disabled=@disabled}}
      @value={{this.newValue}}
      @valueProperty={{null}}
    />
  </template>
}
