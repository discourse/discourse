import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { empty, reads } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import ComboBox from "select-kit/components/combo-box";

@classNames("value-list")
export default class ValueList extends Component {
  @empty("newValue") inputInvalid;

  inputDelimiter = null;
  inputType = null;
  newValue = "";
  collection = null;
  values = null;
  onChange = null;

  @reads("addKey") noneKey;

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

  @discourseComputed("choices.[]", "collection.[]")
  filteredChoices(choices, collection) {
    return makeArray(choices).filter((i) => !collection.includes(i));
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

  @action
  shift(operation, index) {
    let futureIndex = index + operation;

    if (futureIndex > this.collection.length - 1) {
      futureIndex = 0;
    } else if (futureIndex < 0) {
      futureIndex = this.collection.length - 1;
    }

    const shiftedValue = this.collection[index];
    this.collection.removeAt(index);
    this.collection.insertAt(futureIndex, shiftedValue);

    this._saveValues();
  }

  _addValue(value) {
    this.collection.addObject(value);

    if (this.choices) {
      this.set("choices", this.choices.rejectBy("id", value));
    } else {
      this.set("choices", []);
    }

    this._saveValues();
  }

  _removeValue(value) {
    this.collection.removeObject(value);

    if (this.choices) {
      this.set("choices", this.choices.concat([value]).uniq());
    } else {
      this.set("choices", makeArray(value));
    }

    this._saveValues();
  }

  _replaceValue(index, newValue) {
    this.collection.replace(index, 1, [newValue]);
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

  @discourseComputed("collection")
  showUpDownButtons(collection) {
    return collection.length - 1 ? true : false;
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
      <div class="values">
        {{#each this.collection as |value index|}}
          <div data-index={{index}} class="value">
            <DButton
              @action={{fn this.removeValue value}}
              @icon="xmark"
              class="btn-default remove-value-btn btn-small"
            />

            <Input
              title={{value}}
              @value={{value}}
              class="value-input"
              {{on "focusout" (fn this.changeValue index)}}
            />

            {{#if this.showUpDownButtons}}
              <DButton
                @action={{fn this.shift -1 index}}
                @icon="arrow-up"
                class="btn-default shift-up-value-btn btn-small"
              />
              <DButton
                @action={{fn this.shift 1 index}}
                @icon="arrow-down"
                class="btn-default shift-down-value-btn btn-small"
              />
            {{/if}}
          </div>
        {{/each}}
      </div>
    {{/if}}

    <ComboBox
      @valueProperty={{null}}
      @nameProperty={{null}}
      @value={{this.newValue}}
      @content={{this.filteredChoices}}
      @onChange={{this.selectChoice}}
      @options={{hash allowAny=true none=this.noneKey}}
    />
  </template>
}
