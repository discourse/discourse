import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
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
import scrollIntoView from "discourse/modifiers/scroll-into-view";
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
    // Reset preselection on dropdown open to prevent unwanted scrolling
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

      // Only toggle if we have a preselected item and it's in the available options
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

    // Reset preselected item since the available options will change
    this.preselectedItem = null;

    this.args.onChange?.(
      this.args.selection?.filter((item) => !this.compare(item, selectedItem))
    );
  }

  @action
  toggle(result, event) {
    event?.stopPropagation();

    const currentSelection = makeArray(this.args.selection);

    // Check if item is already selected
    if (currentSelection.some((item) => this.compare(item, result))) {
      return; // Don't add duplicates
    }

    // Reset preselected item since the available options will change
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

  #resolveAsyncData(asyncData, context, resolve, reject) {
    return asyncData(context).then(resolve).catch(reject);
  }

  <template>
    <DMenu
      @identifier="d-multi-select"
      @triggerComponent={{element "div"}}
      @triggerClass={{concatClass (if this.hasSelection "--has-selection")}}
      @visibilityOptimizer={{@visibilityOptimizer}}
      @placement={{@placement}}
      @allowedPlacements={{@allowedPlacements}}
      @offset={{@offset}}
      @matchTriggerMinWidth={{@matchTriggerMinWidth}}
      @matchTriggerWidth={{@matchTriggerWidth}}
      ...attributes
    >
      <:trigger>
        {{#if @selection}}
          <div class="d-multi-select-trigger__selection">
            {{#each @selection as |item|}}
              <button
                class="d-multi-select-trigger__selected-item"
                {{on "click" (fn this.remove item)}}
                title={{this.getDisplayText item}}
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
            {{#if this.availableOptions.length}}
              <div class="d-multi-select__search-results">
                {{#each this.availableOptions as |result|}}
                  <menu.item
                    class={{concatClass
                      "d-multi-select__result"
                      (if (eq result this.preselectedItem) "--preselected" "")
                    }}
                    role="button"
                    title={{this.getDisplayText result}}
                    {{scrollIntoView (eq result this.preselectedItem)}}
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
                {{i18n "multi_select.no_results"}}
              </div>
            {{/if}}
          {{/if}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
