import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { gt, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

// args: onChange, inputDelimiter, values, allowAny, choices
export default class SimpleList extends Component {
  @tracked newValue = "";

  @cached
  get collection() {
    return new TrackedArray(
      this.args.values
        ?.split(this.args.inputDelimiter || "\n")
        .filter(Boolean) || []
    );
  }

  get isPredefinedList() {
    return !this.args.allowAny && this.args.choices?.length > 0;
  }

  get validValues() {
    return this.args.choices?.filter((name) => !this.collection.includes(name));
  }

  @action
  keyDown(event) {
    if (event.key === "Enter") {
      this.addValue(this.newValue);
    }
  }

  @action
  changeValue(index, event) {
    this.collection[index] = event.target.value;
    this.args.onChange?.(this.collection);
  }

  @action
  addValue(value) {
    if (!value) {
      return;
    }

    this.newValue = null;
    this.collection.push(value);
    this.args.onChange?.(this.collection);
  }

  @action
  removeAt(index) {
    this.collection.splice(index, 1);
    this.args.onChange?.(this.collection);
  }

  @action
  shift(index, offset) {
    let futureIndex = index + offset;

    if (futureIndex > this.collection.length - 1) {
      futureIndex = 0;
    } else if (futureIndex < 0) {
      futureIndex = this.collection.length - 1;
    }

    const shiftedValue = this.collection[index];
    this.collection.splice(index, 1);
    this.collection.splice(futureIndex, 0, shiftedValue);

    this.args.onChange?.(this.collection);
  }

  <template>
    <div class="simple-list value-list" ...attributes>
      {{#if this.collection}}
        <div class="values">
          {{this.collection.length}}
          {{#each this.collection as |value index|}}
            <div data-index={{index}} class="value">
              <DButton
                @action={{fn this.removeAt index}}
                @icon="xmark"
                class="btn-default remove-value-btn btn-small"
              />

              <input
                {{on "focusout" (fn this.changeValue index)}}
                value={{value}}
                title={{value}}
                type="text"
                class="value-input"
              />

              {{#if (gt this.collection.length 1)}}
                <DButton
                  @action={{fn this.shift index -1}}
                  @icon="arrow-up"
                  class="btn-default shift-up-value-btn btn-small"
                />
                <DButton
                  @action={{fn this.shift index 1}}
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
          {{#if this.validValues}}
            <ComboBox
              @content={{this.validValues}}
              @value={{this.newValue}}
              @onChange={{this.addValue}}
              @valueProperty={{@setting.computedValueProperty}}
              @nameProperty={{@setting.computedNameProperty}}
              @options={{hash castInteger=true allowAny=false}}
              class="add-value-input"
            />
          {{/if}}
        {{else}}
          <input
            {{on "input" (withEventValue (fn (mut this.newValue)))}}
            {{on "keydown" this.keyDown}}
            value={{this.newValue}}
            type="text"
            placeholder={{i18n "admin.site_settings.simple_list.add_item"}}
            autocomplete="off"
            autocorrect="off"
            autocapitalize="off"
            class="add-value-input"
          />
          <DButton
            @action={{fn this.addValue this.newValue}}
            @disabled={{not this.newValue}}
            @icon="plus"
            class="add-value-btn btn-small"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
