import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import TextField from "discourse/components/text-field";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import element from "discourse/helpers/element";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

class Skeleton extends Component {
  get width() {
    return htmlSafe(`width: ${Math.floor(Math.random() * 70) + 20}%`);
  }

  <template>
    <div class="d-multi-select__skeleton">
      <div class="d-multi-select__skeleton-checkbox" />
      <div class="d-multi-select__skeleton-text" style={{this.width}} />
    </div>
  </template>
}

export default class DMultiSelect extends Component {
  @tracked searchTerm = "";

  @tracked preselectedItem = null;

  compareKey = "id";

  get hasSelection() {
    return this.args.selection?.length > 0;
  }

  get label() {
    return this.args.label ?? i18n("multi_select.label");
  }

  @cached
  get data() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const value = new Promise((resolve, reject) => {
      discourseDebounce(
        this,
        this.#resolveAsyncData,
        this.args.loadFn,
        this.searchTerm,
        resolve,
        reject,
        INPUT_DELAY
      );
    });

    return new TrackedAsyncData(value);
  }

  @action
  search(event) {
    this.preselectedItem = null;
    this.searchTerm = event.target.value;
  }

  @action
  focus(input) {
    input.focus();
  }

  @action
  handleKeydown(event) {
    if (!this.data.isResolved) {
      return;
    }

    if (event.key === "Enter") {
      event.preventDefault();

      if (this.preselectedItem) {
        this.toggle(this.preselectedItem, event);
      }
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();

      if (!this.data.value?.length) {
        return;
      }

      if (this.preselectedItem === null) {
        this.preselectedItem = this.data.value[0];
      } else {
        const currentIndex = this.data.value.findIndex((item) =>
          this.compare(item, this.preselectedItem)
        );

        if (currentIndex < this.data.value.length - 1) {
          this.preselectedItem = this.data.value[currentIndex + 1];
        }
      }
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();

      if (!this.data.value?.length) {
        return;
      }

      if (this.preselectedItem === null) {
        this.preselectedItem = this.data.value[0];
      } else {
        const currentIndex = this.data.value.findIndex((item) =>
          this.compare(item, this.preselectedItem)
        );

        if (currentIndex > 0) {
          this.preselectedItem = this.data.value[currentIndex - 1];
        }
      }
    }
  }

  @action
  remove(selectedItem, event) {
    event?.stopPropagation();

    this.args.onChange?.(
      this.args.selection?.filter((item) => !this.compare(item, selectedItem))
    );
  }

  @action
  isSelected(result) {
    return this.args.selection?.filter((item) => this.compare(item, result))
      .length;
  }

  @action
  toggle(result, event) {
    event?.stopPropagation();

    if (this.isSelected(result)) {
      this.remove(result, event);
    } else {
      this.args.onChange?.(makeArray(this.args.selection).concat(result));
    }
  }

  @action
  compare(a, b) {
    if (this.args.compareFn) {
      return this.args.compareFn(a, b);
    } else {
      return a[this.compareKey] === b[this.compareKey];
    }
  }

  #resolveAsyncData(asyncData, context, resolve, reject) {
    return asyncData(context).then(resolve).catch(reject);
  }

  <template>
    <DMenu
      @identifier="d-multi-select"
      @triggerComponent={{element "div"}}
      @triggerClass={{concatClass (if this.hasSelection "--has-selection")}}
      ...attributes
    >
      <:trigger>
        {{#if @selection}}
          <div class="d-multi-select-trigger__selection">
            {{#each @selection as |item|}}
              <button
                class="d-multi-select-trigger__selected-item"
                {{on "click" (fn this.remove item)}}
              >
                <span class="d-multi-select-trigger__selection-label">{{yield
                    item
                    to="selection"
                  }}</span>
                {{icon
                  "xmark"
                  class="d-multi-select-trigger__remove-selection-icon"
                }}
              </button>
            {{/each}}
          </div>
        {{else}}
          <span class="d-multi-select-trigger__label">{{this.label}}</span>
        {{/if}}

        <DButton
          @icon="angle-down"
          class="d-multi-select-trigger__expand-btn btn-transparent"
          @action={{@componentArgs.show}}
        />
      </:trigger>
      <:content>
        <DropdownMenu class="d-multi-select__content" as |menu|>
          <menu.item class="d-multi-select__search-container">
            {{icon "magnifying-glass"}}
            <TextField
              class="d-multi-select__search-input"
              autocomplete="off"
              @placeholder={{i18n "multi_select.search"}}
              @type="search"
              {{on "input" this.search}}
              {{on "keydown" this.handleKeydown}}
              {{didInsert this.focus}}
              @value={{readonly this.searchTerm}}
            />
          </menu.item>

          <menu.divider />

          {{#if this.data.isPending}}
            <div class="d-multi-select__skeletons">
              <Skeleton />
              <Skeleton />
              <Skeleton />
              <Skeleton />
              <Skeleton />
            </div>
          {{else if this.data.isRejected}}
            <div class="d-multi-select__error">
              {{yield this.data.error to="error"}}
            </div>
          {{else if this.data.isResolved}}
            {{#if this.data.value}}
              <div class="d-multi-select__search-results">
                {{#each this.data.value as |result|}}
                  <menu.item
                    class={{concatClass
                      "d-multi-select__result"
                      (if (eq result this.preselectedItem) "--preselected" "")
                    }}
                    role="button"
                    {{on "mouseenter" (fn (mut this.preselectedItem) result)}}
                    {{on "click" (fn this.toggle result)}}
                  >
                    <Input
                      @type="checkbox"
                      @checked={{this.isSelected result}}
                      class="d-multi-select__result-checkbox"
                    />

                    <span class="d-multi-select__result-label">
                      {{yield result to="result"}}
                    </span>
                  </menu.item>
                {{/each}}
              </div>
            {{else}}
              <div class="d-multi-select__search-no-results">
                {{i18n "multi_select.no_results"}}
              </div>
            {{/if}}
          {{/if}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
