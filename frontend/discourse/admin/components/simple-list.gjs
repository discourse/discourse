import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import { gt, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

// args: onChange, inputDelimiter, values, allowAny, choices
export default class SimpleList extends Component {
  @tracked newValue = "";

  @cached
  get collection() {
    return trackedArray(
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
  removeItem(index) {
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
          {{#each this.collection as |value index|}}
            <div class="value" data-index={{index}}>
              <DButton
                class="btn-default remove-value-btn btn-small"
                @action={{fn this.removeItem index}}
                @icon="xmark"
              />

              <input
                class="value-input"
                title={{value}}
                type="text"
                value={{value}}
                {{on "focusout" (fn this.changeValue index)}}
              />

              {{#if (gt this.collection.length 1)}}
                <DButton
                  class="btn-default shift-up-value-btn btn-small"
                  @action={{fn this.shift index -1}}
                  @icon="arrow-up"
                />
                <DButton
                  class="btn-default shift-down-value-btn btn-small"
                  @action={{fn this.shift index 1}}
                  @icon="arrow-down"
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
              class="add-value-input"
              @content={{this.validValues}}
              @nameProperty={{@setting.computedNameProperty}}
              @onChange={{this.addValue}}
              @options={{hash castInteger=true allowAny=false}}
              @value={{this.newValue}}
              @valueProperty={{@setting.computedValueProperty}}
            />
          {{/if}}
        {{else}}
          <input
            autocapitalize="off"
            autocomplete="off"
            autocorrect="off"
            class="add-value-input"
            placeholder={{i18n "admin.site_settings.simple_list.add_item"}}
            type="text"
            value={{this.newValue}}
            {{on "input" (withEventValue (fn (mut this.newValue)))}}
            {{on "keydown" this.keyDown}}
          />
          <DButton
            class="add-value-btn btn-default btn-small"
            @action={{fn this.addValue this.newValue}}
            @disabled={{not this.newValue}}
            @icon="plus"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
