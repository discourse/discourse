// @ts-check
/* eslint-disable ember/no-side-effects */
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { trustHTML } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
/** @type {import("discourse/float-kit/components/d-menu.gjs")} */
import DMenu from "discourse/float-kit/components/d-menu";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { makeArray } from "discourse/lib/helpers";
import { eq } from "discourse/truth-helpers";
/** @type {import("discourse/ui-kit/d-button.gjs").default} */
import DButton from "discourse/ui-kit/d-button";
/** @type {import("discourse/ui-kit/d-dropdown-menu.gjs").default} */
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DTextField from "discourse/ui-kit/d-text-field";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
/** @type {import("discourse/ui-kit/helpers/d-element.gjs").default} */
import dElement from "discourse/ui-kit/helpers/d-element";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dScrollIntoView from "discourse/ui-kit/modifiers/d-scroll-into-view";
import { i18n } from "discourse-i18n";

class Skeleton extends Component {
  get width() {
    return trustHTML(`width: ${Math.floor(Math.random() * 70) + 20}%`);
  }

  <template>
    <div class="d-multi-select__skeleton">
      <div class="d-multi-select__skeleton-checkbox" />
      <div class="d-multi-select__skeleton-text" style={{this.width}} />
    </div>
  </template>
}

/**
 * A typeahead picker that lets the user build up a selection from an
 * asynchronously-loaded list. The component owns the search box, the
 * keyboard navigation (`ArrowUp` / `ArrowDown` / `Enter`), and the
 * loading/error/no-results states; the consumer owns the data fetch and the
 * selection state.
 *
 * The picker is **controlled**: `@selection` is the source of truth, and
 * `@onChange` is invoked with the new array whenever the user adds or
 * removes an item. The component does not maintain its own selection state.
 *
 * Items are compared by `id` by default. Override with `@compareFn` when
 * items are matched on a different key.
 *
 * Three named blocks let the consumer render their own data:
 * - `<:selection>` — how each selected pill displays
 * - `<:result>` — how each dropdown row displays
 * - `<:error>` — how a failed `@loadFn` is shown
 *
 * @example
 * <DMultiSelect
 *   @selection={{this.tags}}
 *   @onChange={{this.updateTags}}
 *   @loadFn={{this.searchTags}}
 * >
 *   <:selection as |tag|>{{tag.name}}</:selection>
 *   <:result as |tag|>{{tag.name}}</:result>
 *   <:error as |err|>{{err.message}}</:error>
 * </DMultiSelect>
 */

/**
 * @typedef DMultiSelectSignature
 *
 * @property {object} Args
 *
 * @property {Array<object>} [Args.selection] Currently-selected items. The component compares against this array to filter out already-selected results.
 * @property {(newSelection: Array<object>) => void} [Args.onChange] Invoked with the new full selection array whenever an item is added or removed.
 * @property {(searchTerm: string) => Promise<Array<object>>} Args.loadFn Required. Fetches the candidate options for a given search term. Called (debounced) every time the search input changes.
 * @property {(a: object, b: object) => boolean} [Args.compareFn] Custom equality check for items. Defaults to comparing the `id` field.
 * @property {string} [Args.label] Trigger text shown when no items are selected. Defaults to the i18n string `multi_select.label`.
 * @property {string} [Args.noResultsLabel] Empty-state text shown inside the dropdown when the search returns no items. Defaults to the i18n string `multi_select.no_results`.
 * @property {string} [Args.contentClass] Extra classes joined onto the dropdown menu wrapper.
 *
 * DMenu pass-through (see `DMenu` for the full semantics).
 *
 * @property {boolean} [Args.visibilityOptimizer]
 * @property {string} [Args.placement]
 * @property {Array<string>} [Args.allowedPlacements]
 * @property {number} [Args.offset]
 * @property {boolean} [Args.matchTriggerMinWidth]
 * @property {boolean} [Args.matchTriggerWidth]
 * @property {Function} [Args.onRegisterDMenuApi] Called with the DMenu instance once mounted. Use to programmatically open/close the menu from the consumer.
 *
 * @property {HTMLDivElement} Element The DMenu trigger wrapper (`<div class="d-multi-select-trigger">`).
 *
 * @property {object} Blocks
 * @property {[object]} Blocks.selection Renders one selected-item pill. Receives the item.
 * @property {[object]} Blocks.result Renders one dropdown row. Receives the item.
 * @property {[unknown]} Blocks.error Renders the error state when `@loadFn` rejects. Receives the error.
 */

/** @extends {Component<DMultiSelectSignature>} */
export default class DMultiSelect extends Component {
  @tracked searchTerm = "";

  @tracked preselectedItem = null;

  compareKey = "id";
  #promise = null;

  @cached
  get validateArgs() {
    if (DEBUG) {
      assert(
        "[d-multi-select] @loadFn is required",
        typeof this.args.loadFn === "function"
      );
    }
    return null;
  }

  get hasSelection() {
    return this.args.selection?.length > 0;
  }

  get label() {
    return this.args.label ?? i18n("multi_select.label");
  }

  get noResultsLabel() {
    return this.args.noResultsLabel ?? i18n("multi_select.no_results");
  }

  @cached
  get data() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    let promise = this.#promise?.promise;

    if (promise) {
      this.#debounceSearch();
    } else {
      let resolve, reject;

      promise = new Promise((res, rej) => {
        this.#debounceSearch();
        resolve = res;
        reject = rej;
      });

      this.#promise = { promise, resolve, reject };
    }

    return new TrackedAsyncData(promise);
  }

  #debounceSearch() {
    discourseDebounce(
      this,
      this.#resolveAsyncData,
      this.args.loadFn,
      this.searchTerm,
      INPUT_DELAY
    );
  }

  get availableOptions() {
    if (!this.data.isResolved || !this.data.value) {
      return this.data.value;
    }

    return this.data.value.filter(
      (item) =>
        !this.args.selection?.some((selected) => this.compare(item, selected))
    );
  }

  @action
  search(event) {
    this.preselectedItem = null;
    this.searchTerm = event.target.value;
  }

  @action
  focus(input) {
    // Reset preselection on dropdown open to prevent unwanted scrolling.
    this.preselectedItem = null;
    input.focus({ preventScroll: true });
  }

  @action
  handleKeydown(event) {
    if (!this.data.isResolved) {
      return;
    }

    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();

      // Only toggle when there's a preselected item that's still in the
      // available options (it may have been removed by a concurrent change).
      if (
        this.preselectedItem &&
        this.availableOptions?.some((item) =>
          this.compare(item, this.preselectedItem)
        )
      ) {
        this.toggle(this.preselectedItem, event);
      }
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();

      if (!this.availableOptions?.length) {
        return;
      }

      if (this.preselectedItem === null) {
        this.preselectedItem = this.availableOptions[0];
      } else {
        const currentIndex = this.availableOptions.findIndex((item) =>
          this.compare(item, this.preselectedItem)
        );

        if (currentIndex < this.availableOptions.length - 1) {
          this.preselectedItem = this.availableOptions[currentIndex + 1];
        }
      }
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();

      if (!this.availableOptions?.length) {
        return;
      }

      if (this.preselectedItem === null) {
        this.preselectedItem = this.availableOptions[0];
      } else {
        const currentIndex = this.availableOptions.findIndex((item) =>
          this.compare(item, this.preselectedItem)
        );

        if (currentIndex > 0) {
          this.preselectedItem = this.availableOptions[currentIndex - 1];
        }
      }
    }
  }

  @action
  remove(selectedItem, event) {
    event?.stopPropagation();

    if (selectedItem.preventRemoval) {
      return;
    }

    // Reset preselected item since the available options will change.
    this.preselectedItem = null;

    this.args.onChange?.(
      this.args.selection?.filter((item) => !this.compare(item, selectedItem))
    );
  }

  @action
  toggle(result, event) {
    event?.stopPropagation();

    const currentSelection = makeArray(this.args.selection);

    // Don't add duplicates.
    if (currentSelection.some((item) => this.compare(item, result))) {
      return;
    }

    // Reset preselected item since the available options will change.
    this.preselectedItem = null;

    this.args.onChange?.(currentSelection.concat(result));
  }

  @action
  compare(a, b) {
    if (this.args.compareFn) {
      return this.args.compareFn(a, b);
    } else {
      return a[this.compareKey] === b[this.compareKey];
    }
  }

  getDisplayText(item) {
    return item?.name;
  }

  #resolveAsyncData(asyncData, context) {
    const { resolve, reject } = this.#promise;

    return asyncData(context)
      .then(resolve)
      .catch(reject)
      .finally(() => {
        this.#promise = null;
      });
  }

  <template>
    {{! @glint-nocheck: integrates classic DTextField with `readonly` helper and a curried DMenu trigger that isn't fully reflected in the JSDoc Signature }}
    {{this.validateArgs}}
    <DMenu
      @identifier="d-multi-select"
      @triggerComponent={{dElement "div"}}
      @triggerClass={{dConcatClass (if this.hasSelection "--has-selection")}}
      @visibilityOptimizer={{@visibilityOptimizer}}
      @placement={{@placement}}
      @allowedPlacements={{@allowedPlacements}}
      @offset={{@offset}}
      @matchTriggerMinWidth={{@matchTriggerMinWidth}}
      @matchTriggerWidth={{@matchTriggerWidth}}
      @onRegisterApi={{@onRegisterDMenuApi}}
      ...attributes
    >
      <:trigger>
        {{#if @selection}}
          <div class="d-multi-select-trigger__selection">
            {{#each @selection as |item|}}
              <button
                type="button"
                class="d-multi-select-trigger__selected-item"
                {{on "click" (fn this.remove item)}}
                title={{this.getDisplayText item}}
              >
                <span class="d-multi-select-trigger__selection-label">{{yield
                    item
                    to="selection"
                  }}</span>

                {{#unless item.preventRemoval}}
                  {{dIcon
                    "xmark"
                    class="d-multi-select-trigger__remove-selection-icon"
                  }}
                {{/unless}}
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
        <DDropdownMenu
          class={{dConcatClass "d-multi-select__content" @contentClass}}
          as |menu|
        >
          <menu.item class="d-multi-select__search-container">
            {{dIcon "magnifying-glass"}}
            <DTextField
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
            {{#if this.availableOptions.length}}
              <div class="d-multi-select__search-results">
                {{#each this.availableOptions as |result|}}
                  <menu.item
                    class={{dConcatClass
                      "d-multi-select__result"
                      (if (eq result this.preselectedItem) "--preselected" "")
                    }}
                    role="button"
                    title={{this.getDisplayText result}}
                    {{dScrollIntoView (eq result this.preselectedItem)}}
                    {{on "mouseenter" (fn (mut this.preselectedItem) result)}}
                    {{on "click" (fn this.toggle result)}}
                  >
                    <span class="d-multi-select__result-label">
                      {{yield result to="result"}}
                    </span>
                  </menu.item>
                {{/each}}
              </div>
            {{else}}
              <div class="d-multi-select__search-no-results">
                {{this.noResultsLabel}}
              </div>
            {{/if}}
          {{/if}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
