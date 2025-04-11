import { arrayContentDidChange } from "@ember/-internals/metal";
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import { classNameBindings } from "@ember-decorators/component";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

@classNameBindings(":simple-list", ":value-list")
export default class SimpleList extends Component {
  @empty("newValue") inputEmpty;

  inputDelimiter = null;
  newValue = "";
  collection = null;
  values = null;
  choices = null;
  allowAny = false;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    this.set("collection", this._splitValues(this.values, this.inputDelimiter));
    this.set("isPredefinedList", !this.allowAny && !isEmpty(this.choices));
  }

  keyDown(event) {
    if (event.which === 13) {
      this.addValue(this.newValue);
      return;
    }
  }

  @action
  changeValue(index, event) {
    this.collection.replace(index, 1, [event.target.value]);
    arrayContentDidChange(this.collection, index);
    this._onChange();
  }

  @action
  addValue(newValue) {
    if (!newValue) {
      return;
    }

    this.set("newValue", null);
    this.collection.addObject(newValue);
    this._onChange();
  }

  @action
  removeValue(value) {
    this.collection.removeObject(value);
    this._onChange();
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

    this._onChange();
  }

  _onChange() {
    this.onChange?.(this.collection);
  }

  @discourseComputed("choices", "values")
  validValues(choices, values) {
    return choices.filter((name) => !values.includes(name));
  }

  @discourseComputed("collection")
  showUpDownButtons(collection) {
    return collection.length - 1 ? true : false;
  }

  _splitValues(values, delimiter) {
    return values && values.length
      ? values.split(delimiter || "\n").filter(Boolean)
      : [];
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

    <div class="simple-list-input">
      {{#if this.isPredefinedList}}
        {{#if (gt this.validValues.length 0)}}
          <ComboBox
            @content={{this.validValues}}
            @value={{this.newValue}}
            @onChange={{this.addValue}}
            @valueProperty={{this.setting.computedValueProperty}}
            @nameProperty={{this.setting.computedNameProperty}}
            @options={{hash castInteger=true allowAny=false}}
            class="add-value-input"
          />
        {{/if}}
      {{else}}
        <Input
          @type="text"
          @value={{this.newValue}}
          placeholder={{i18n "admin.site_settings.simple_list.add_item"}}
          class="add-value-input"
          autocomplete="off"
          autocorrect="off"
          autocapitalize="off"
        />
        <DButton
          @action={{fn this.addValue this.newValue}}
          @disabled={{this.inputEmpty}}
          @icon="plus"
          class="add-value-btn btn-small"
        />
      {{/if}}
    </div>
  </template>
}
