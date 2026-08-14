import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

const INDEX_KEY = "@index";

// args: onChange, inputDelimiter, values, allowAny, choices
export default class SimpleList extends Component {
  @tracked newValue = "";

  valueLabel = (value) => value;

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

  /**
   * Applies a committed move onto the delimited collection and reports the
   * new order. Wrapping and announcements are the list's own.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.collection.splice(0, this.collection.length, ...move.proposedToItems);
    this.args.onChange?.(this.collection);
  }

  <template>
    <div class="simple-list value-list" ...attributes>
      <DReorderableList
        @items={{this.collection}}
        @key={{INDEX_KEY}}
        @label={{this.valueLabel}}
        @onMove={{this.handleMove}}
        @wrap={{true}}
        @arrowsLayout="inline"
        @controls="end"
        @controlsVisibility="reveal"
        @tag="div"
        @itemTag="div"
        @rowClass="value"
        class="values"
      >
        <:default as |value row|>
          <DButton
            @action={{fn this.removeItem row.index}}
            @icon="xmark"
            class="btn-default remove-value-btn btn-small"
          />

          <input
            {{on "focusout" (fn this.changeValue row.index)}}
            value={{value}}
            title={{value}}
            type="text"
            class="value-input"
          />
        </:default>
      </DReorderableList>

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
            class="add-value-btn btn-default btn-small"
          />
        {{/if}}
      </div>
    </div>
  </template>
}
