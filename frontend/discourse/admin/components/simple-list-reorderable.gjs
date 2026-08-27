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
/**
 * The reordering surface behind `enable_new_reordering_controls`. Mirrors
 * `simple-list.gjs`, over the shared reorderable list.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over `simple-list.gjs`
 * and drop the branch in the site-settings and logo-form call sites.
 */
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
  removeValue(value, index) {
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
        @onRemove={{this.removeValue}}
        @tag="div"
        @itemTag="div"
        @rowClass="value --reorderable"
        class="values --reorderable"
      >
        <:row as |value controls|>
          {{#if this.isPredefinedList}}
            {{! A closed set has nothing to type: the value came from the
              choices and can only be reordered or removed. }}
            <span
              class="value-input --readonly"
              title={{value}}
            >{{value}}</span>
          {{else}}
            <input
              {{on "focusout" (fn this.changeValue controls.index)}}
              value={{value}}
              title={{value}}
              type="text"
              class="value-input"
            />
          {{/if}}
        </:row>
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
              {{! Without a `none` label the closed-set picker renders as an
                empty box under the list. The free-text branch below shows the
                same string as its placeholder. }}
              @options={{hash
                castInteger=true
                allowAny=false
                none="admin.site_settings.simple_list.add_item"
              }}
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
