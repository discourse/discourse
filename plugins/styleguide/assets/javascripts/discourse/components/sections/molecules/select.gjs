import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import StyleguideExample from "../../styleguide-example";
import SelectShowcases from "./select-showcases";

function delay(signal, milliseconds = 750) {
  return new Promise((resolve, reject) => {
    const onAbort = () => {
      clearTimeout(timeout);
      reject(signal.reason ?? new DOMException("Aborted", "AbortError"));
    };
    const timeout = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, milliseconds);

    if (signal.aborted) {
      onAbort();
    } else {
      signal.addEventListener("abort", onAbort, { once: true });
    }
  });
}

export default class Select extends Component {
  @tracked asyncButtonValue = null;
  @tracked defaultValue = null;
  @tracked emptyValue = null;
  @tracked errorValue = null;
  @tracked multiValue = [];
  @tracked maximumValue = [1, 2, 3];
  @tracked staticValue = null;
  @tracked clearableValue = 1;
  @tracked clearableMultiValue = [1, 2];
  @tracked iconValue = null;
  @tracked caretValue = null;
  @tracked disabledValue = 1;
  @tracked readonlyValue = 1;
  @tracked minCharsValue = null;
  @tracked customEmptyValue = null;
  @tracked placementValue = null;
  @tracked debounceValue = null;
  @tracked eventsValue = null;
  @tracked largeListValue = null;
  @tracked pagedValue = null;
  @tracked pagedCursorValue = null;
  @tracked openCount = 0;
  @tracked closeCount = 0;

  errorRequestCount = 0;

  defaultCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;

  pagedCode = `{{! The source pages; the engine accumulates and caps }}
<DSelect
  @load={{this.loadPage}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>

// (filter, { offset, limit, signal }) => one of:
//   { items, total }    a known set size; paging stops when it is reached
//   { items, hasMore }  more-ness without a size; size is known once hasMore is false
//   items               a bare array: this IS the whole set, so no second page is fetched
//
// A source that paginates MUST report total or hasMore. Say nothing and the
// engine takes the first response as complete.`;

  largeListCode = `{{! 5000 items rendered in full; only the rows in view are mounted }}
<DSelect
  @items={{this.hugeList}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;

  asyncButtonCode = `<DSelect
  @load={{this.loadOptions}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  staticCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="static"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  multiCode = `<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  maximumCode = `<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @maximum={{3}}
  @value={{this.value}}
  @onChange={{this.onChange}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  emptyCode = `<DSelect
  @load={{this.loadEmpty}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  clearableCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @clearable={{true}}
/>`;

  clearableMultiCode = `<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @clearable={{true}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  iconCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @icon="tag"
  @variant="static"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  caretCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @caretIcon={{hash open="caret-up" closed="caret-down"}}
  @variant="static"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  disabledCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @disabled={{true}}
  @variant="static"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  readonlyCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @readonly={{true}}
  @variant="static"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  minCharsCode = `<DSelect
  @load={{this.loadOptions}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @minChars={{3}}
  @clearable={{true}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  customEmptyCode = `<DSelect
  @load={{this.loadEmpty}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
  <:empty>Nothing matches. Try another term.</:empty>
</DSelect>`;

  placementCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
  @placement="top"
  @offset={{16}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  debounceCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
  @debounce={{300}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  eventsCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @onShow={{this.onShow}}
  @onClose={{this.onClose}}
/>`;

  errorCode = `<DSelect
  @load={{this.loadWithRetry}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  get items() {
    return this.args.dummy.options;
  }

  // Far more than a single virtualized window, so scrolling to the true last row is
  // exercised both by hand and by a system spec.
  get largeListItems() {
    return Array.from({ length: 5000 }, (_, index) => ({
      id: index + 1,
      name: `Option ${index + 1}`,
    }));
  }

  filterItems(filter) {
    const normalizedFilter = filter.toLowerCase();
    return this.items.filter((item) =>
      item.name.toLowerCase().includes(normalizedFilter)
    );
  }

  @action
  async loadEmpty(_filter, { signal }) {
    await delay(signal);
    return [];
  }

  @action
  async loadOptions(filter, { signal }) {
    await delay(signal, 1200);
    return this.filterItems(filter);
  }

  @action
  async loadWithRetry(filter, { signal }) {
    await delay(signal);
    this.errorRequestCount++;

    if (this.errorRequestCount === 1) {
      throw new Error(i18n("styleguide.sections.select.request_error"));
    }

    return this.filterItems(filter);
  }

  @action
  updateAsyncButton(value) {
    this.asyncButtonValue = value;
  }

  @action
  updateLargeList(value) {
    this.largeListValue = value;
  }

  // Slow enough that aria-busy and the "loading more" announcement are perceptible while a
  // page is in flight.
  @action
  async loadPage(filter, { signal, offset = 0, limit = 50 }) {
    await delay(signal, 900);
    const matches = this.largeListItems.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
    return {
      items: matches.slice(offset, offset + limit),
      total: matches.length,
    };
  }

  // A cursor source: it knows another page exists without knowing the set size, so rows
  // report -1 until the last page declares completeness and the real count becomes known.
  @action
  async loadPageCursor(filter, options) {
    const { items, total } = await this.loadPage(filter, options);
    const { offset = 0 } = options;
    return { items, hasMore: offset + items.length < total };
  }

  @action
  updatePaged(value) {
    this.pagedValue = value;
  }

  @action
  updatePagedCursor(value) {
    this.pagedCursorValue = value;
  }

  @action
  updateDefault(value) {
    this.defaultValue = value;
  }

  @action
  updateEmpty(value) {
    this.emptyValue = value;
  }

  @action
  updateError(value) {
    this.errorValue = value;
  }

  @action
  updateMulti(value) {
    this.multiValue = value;
  }

  @action
  updateMaximum(value) {
    this.maximumValue = value;
  }

  @action
  updateStatic(value) {
    this.staticValue = value;
  }

  @action
  updateClearable(value) {
    this.clearableValue = value;
  }

  @action
  updateClearableMulti(value) {
    this.clearableMultiValue = value;
  }

  @action
  updateIcon(value) {
    this.iconValue = value;
  }

  @action
  updateCaret(value) {
    this.caretValue = value;
  }

  @action
  updateDisabled(value) {
    this.disabledValue = value;
  }

  @action
  updateReadonly(value) {
    this.readonlyValue = value;
  }

  @action
  updateMinChars(value) {
    this.minCharsValue = value;
  }

  @action
  updateCustomEmpty(value) {
    this.customEmptyValue = value;
  }

  @action
  updatePlacement(value) {
    this.placementValue = value;
  }

  @action
  updateDebounce(value) {
    this.debounceValue = value;
  }

  @action
  updateEvents(value) {
    this.eventsValue = value;
  }

  @action
  onShow() {
    this.openCount++;
  }

  @action
  onClose() {
    this.closeCount++;
  }

  <template>
    <p class="section-description">
      {{i18n "styleguide.sections.select.description"}}
    </p>
    <p class="styleguide-note select-examples__mobile-note">
      {{i18n "styleguide.sections.select.mobile_guidance"}}
    </p>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.default_example"}}
      @code={{this.defaultCode}}
    >
      <div class="select-examples__control select-examples__default">
        <DSelect
          @items={{this.items}}
          @value={{this.defaultValue}}
          @onChange={{this.updateDefault}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.async_button_example"}}
      @code={{this.asyncButtonCode}}
    >
      <div class="select-examples__control select-examples__async-button">
        <DSelect
          @load={{this.loadOptions}}
          @value={{this.asyncButtonValue}}
          @onChange={{this.updateAsyncButton}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.static_example"}}
      @code={{this.staticCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.staticValue}}
          @onChange={{this.updateStatic}}
          @variant="static"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.multi_example"}}
      @code={{this.multiCode}}
    >
      <div class="select-examples__control select-examples__multi">
        <DSelect
          @items={{this.items}}
          @multiple={{true}}
          @value={{this.multiValue}}
          @onChange={{this.updateMulti}}
          @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.maximum_example"}}
      @code={{this.maximumCode}}
    >
      <div class="select-examples__control select-examples__maximum">
        <DSelect
          @items={{this.items}}
          @multiple={{true}}
          @maximum={{3}}
          @value={{this.maximumValue}}
          @onChange={{this.updateMaximum}}
          @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.empty_example"}}
      @code={{this.emptyCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @load={{this.loadEmpty}}
          @value={{this.emptyValue}}
          @onChange={{this.updateEmpty}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          @noResultsLabel={{i18n "styleguide.sections.select.empty_label"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.clearable_example"}}
      @code={{this.clearableCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.clearableValue}}
          @onChange={{this.updateClearable}}
          @clearable={{true}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.clearable_multi_example"}}
      @code={{this.clearableMultiCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @multiple={{true}}
          @value={{this.clearableMultiValue}}
          @onChange={{this.updateClearableMulti}}
          @clearable={{true}}
          @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.icon_example"}}
      @code={{this.iconCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.iconValue}}
          @onChange={{this.updateIcon}}
          @icon="tag"
          @variant="static"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.caret_example"}}
      @code={{this.caretCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.caretValue}}
          @onChange={{this.updateCaret}}
          @caretIcon={{hash open="caret-up" closed="caret-down"}}
          @variant="static"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.disabled_example"}}
      @code={{this.disabledCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.disabledValue}}
          @onChange={{this.updateDisabled}}
          @disabled={{true}}
          @variant="static"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.readonly_example"}}
      @code={{this.readonlyCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.readonlyValue}}
          @onChange={{this.updateReadonly}}
          @readonly={{true}}
          @variant="static"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.min_chars_example"}}
      @code={{this.minCharsCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @load={{this.loadOptions}}
          @value={{this.minCharsValue}}
          @onChange={{this.updateMinChars}}
          @minChars={{3}}
          @clearable={{true}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.custom_empty_example"}}
      @code={{this.customEmptyCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @load={{this.loadEmpty}}
          @value={{this.customEmptyValue}}
          @onChange={{this.updateCustomEmpty}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
          <:empty>
            {{i18n "styleguide.sections.select.custom_empty_body"}}
          </:empty>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.placement_example"}}
      @code={{this.placementCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.placementValue}}
          @onChange={{this.updatePlacement}}
          @variant="button"
          @placement="top"
          @offset={{16}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.debounce_example"}}
      @code={{this.debounceCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.debounceValue}}
          @onChange={{this.updateDebounce}}
          @variant="button"
          @debounce={{300}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.events_example"}}
      @code={{this.eventsCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.eventsValue}}
          @onChange={{this.updateEvents}}
          @onShow={{this.onShow}}
          @onClose={{this.onClose}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        />
        <p class="styleguide-note">
          {{i18n
            "styleguide.sections.select.events_note"
            opened=this.openCount
            closed=this.closeCount
          }}
        </p>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.large_list_example"}}
      @code={{this.largeListCode}}
    >
      <div class="select-examples__control select-examples__large-list">
        <DSelect
          @items={{this.largeListItems}}
          @value={{this.largeListValue}}
          @onChange={{this.updateLargeList}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        />
        <p class="styleguide-note">
          {{i18n "styleguide.sections.select.large_list_note"}}
        </p>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.paged_example"}}
      @code={{this.pagedCode}}
    >
      <div class="select-examples__control select-examples__paged">
        <DSelect
          @load={{this.loadPage}}
          @value={{this.pagedValue}}
          @onChange={{this.updatePaged}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
        <p class="styleguide-note">
          {{i18n "styleguide.sections.select.paged_note"}}
        </p>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.paged_cursor_example"}}
      @code={{this.pagedCode}}
    >
      <div class="select-examples__control select-examples__paged-cursor">
        <DSelect
          @load={{this.loadPageCursor}}
          @value={{this.pagedCursorValue}}
          @onChange={{this.updatePagedCursor}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
        <p class="styleguide-note">
          {{i18n "styleguide.sections.select.paged_cursor_note"}}
        </p>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.error_example"}}
      @code={{this.errorCode}}
    >
      <div class="select-examples__control select-examples__error">
        <DSelect
          @load={{this.loadWithRetry}}
          @value={{this.errorValue}}
          @onChange={{this.updateError}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <SelectShowcases @categories={{@dummy.categories}} />
  </template>
}
