import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

const INDEX_KEY = "@index";

// args: onChange, inputDelimiter, values, allowAny, choices
/**
 * Renders its rows through the shared reorderable list when
 * `enable_new_reordering_controls` is on, and through the legacy rows
 * otherwise. The branch lives here so every caller follows the change.
 *
 * TODO (ui-kit-reorderable-list-cleanup) delete the legacy arm and the
 * members marked for it once the change ships.
 */
export default class SimpleList extends Component {
  @service siteSettings;

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

  // TODO (ui-kit-reorderable-list-cleanup) delete with the legacy arm below.
  @action
  removeItem(index) {
    this.collection.splice(index, 1);
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
   * @param {import("discourse/ui-kit/d-reorderable-list/types").ReorderableMove<string>} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.collection.splice(0, this.collection.length, ...move.proposedToItems);
    this.args.onChange?.(this.collection);
  }

  // TODO (ui-kit-reorderable-list-cleanup) delete with the legacy arm below.
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
            {{#if this.isPredefinedList}}
              {{! A closed set has nothing to type: the value came from the
                choices and can only be reordered or removed. }}
              <span
                class="value-input --readonly"
                title={{value}}
              >{{value}}</span>
            {{else}}
              <input
                class="value-input"
                title={{value}}
                type="text"
                value={{value}}
                {{on "focusout" (fn this.changeValue controls.index)}}
              />
            {{/if}}
          </:row>
        </DReorderableList>
      {{else}}
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
      {{/if}}

      <div class="simple-list-input">
        {{#if this.isPredefinedList}}
          {{#if this.validValues}}
            <ComboBox
              class="add-value-input"
              @content={{this.validValues}}
              @nameProperty={{@setting.computedNameProperty}}
              @onChange={{this.addValue}}
              {{! Without an empty-selection label the closed-set picker renders
                as an empty box under the reorderable list. The free-text branch
                below shows the same string as its placeholder. }}
              @options={{if
                this.siteSettings.enable_new_reordering_controls
                (hash
                  castInteger=true
                  allowAny=false
                  none="admin.site_settings.simple_list.add_item"
                )
                (hash castInteger=true allowAny=false)
              }}
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
