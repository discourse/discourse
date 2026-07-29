import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  ASYNC_BUTTON_DELAY,
  delay,
  FOUR_OPTIONS,
  LOCALES,
  MAXIMUM,
  notificationLevels,
  PAGE_SIZE,
  topics,
} from "../../../lib/select-fixtures";
import StyleguideExample from "../../styleguide-example";
import StyleguideGroups from "../../styleguide-groups";
import SelectAriaProbe from "./select-aria-probe";
import SelectContent from "./select-content";
import SelectHero from "./select-hero";
import SelectKeyboard from "./select-keyboard";
import SelectShowcases from "./select-showcases";

/**
 * The page's group manifest — the single source of truth for both the sub-navigation and the
 * order groups render in. Each id is also the `?group=` value, so it is part of the page's URL
 * surface and is what system specs navigate to.
 *
 * The order is a narrative: what is this, where do options come from, what happens when it is
 * slow or broken, how do I make it look right, how do I control what a row renders, what can be
 * picked, is it accessible, where does it bend, and finally what it looks like doing real work.
 */
const GROUPS = [
  "start",
  "data",
  "states",
  "appearance",
  "content",
  "selection",
  "keyboard",
  "limits",
  "pickers",
];

export default class Select extends Component {
  @tracked asyncButtonValue = null;

  @tracked defaultValue = null;

  @tracked emptyValue = null;

  @tracked errorValue = null;

  @tracked multiValue = [];
  @tracked toggleValue = ["en", "pt-BR"];

  @tracked maximumValue = ["en", "es", "pt-BR"];

  @tracked staticValue = null;

  @tracked clearableValue = "es";

  @tracked clearableMultiValue = ["en", "es"];

  @tracked iconValue = null;
  @tracked iconFollowsValue = "tracking";
  @tracked caretValue = null;
  @tracked noneValue = "es";
  @tracked iconOnlyValue = "watching";
  @tracked disabledValue = "en";
  @tracked readonlyValue = "en";
  @tracked minCharsValue = null;
  @tracked placementValue = null;
  @tracked debounceValue = null;
  @tracked debounceKeystrokes = 0;
  @tracked debounceQueries = [];
  @tracked eventsValue = null;
  @tracked largeListValue = null;
  @tracked pagedValue = null;
  @tracked pagedCursorValue = null;
  @tracked fastReloadValue = null;
  @tracked slowReloadValue = null;
  @tracked openCount = 0;
  @tracked closeCount = 0;

  errorRequestCount = 0;

  items = LOCALES;
  fourOptions = FOUR_OPTIONS;
  defaultCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;
  pagedCode = `{{! The source pages; the engine accumulates and caps }}
<DSelect
  @load={{this.loadPage}}
  @value={{this.value}}
  @resolveValue={{this.resolveTopic}}
  @onChange={{this.onChange}}
/>

{{! The load function is (filter, { offset, limit, signal }) and returns one of:

  { items, total }    a known set size; paging stops when it is reached
  { items, hasMore }  more-ness without a size; the size is known once hasMore is false
  items               a bare array: this IS the whole set, so no second page is fetched

  A source that paginates MUST report total or hasMore. Say nothing and the engine
  takes the first response as complete. }}`;
  reloadCode = `{{! Nothing to configure: the delay decides which behaviour you get }}
<DSelect
  @load={{this.loadPage}}
  @value={{this.value}}
  @resolveValue={{this.resolveTopic}}
  @onChange={{this.onChange}}
/>

{{! While a NEW query is in flight the previous rows are kept, so a source that answers
  quickly never blinks. Past ~250ms they are dropped for the skeleton instead: those rows
  no longer match what the input says, and they stay clickable, so an Enter would land on
  a row the query excludes.

  A reveal — another page for the SAME query — is not affected. Its rows are still
  correct, so they stay put with placeholders appended at the frontier. }}`;
  largeListCode = `{{! 5000 items rendered in full; only the rows in view are mounted }}
<DSelect
  @items={{this.hugeList}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;
  asyncButtonCode = `<DSelect
  @load={{this.loadOptions}}
  @value={{this.value}}
  @resolveValue={{this.resolveOption}}
  @onChange={{this.onChange}}
  @variant="button"
/>`;
  staticCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="static"
/>`;
  toggleCode = `{{! Nothing here turns it into a panel of toggles: a multi-select already keeps
  the list open on a pick, and each row draws its own checked/unchecked box }}
<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @variant="button"
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;

  multiCode = `<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;
  maximumCode = `<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @maximum={{3}}
  @value={{this.value}}
  @onChange={{this.onChange}}
/>`;

  noneCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @noneLabel="None"
/>`;

  iconOnlyCode = `{{! The consumer owns @value, so it drives @icon from the selection }}
<DSelect
  @items={{this.levels}}
  @variant="static"
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="level"
  @labelField="title"
  @icon={{this.iconForValue}}
  @iconOnly={{true}}
  @label="Notification level"
/>`;

  emptyCode = `<DSelect
  @load={{this.loadEmpty}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
/>`;

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
/>`;

  iconCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @icon="globe"
  @variant="static"
/>`;

  iconFollowsCode = `{{! @icon is derived from @value by the consumer; the component never picks
  a glyph for you. Contrast the fixed icon above, which names the field. }}
<DSelect
  @items={{this.levels}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @valueField="level"
  @labelField="title"
  @icon={{this.iconForValue}}
  @variant="static"
/>`;

  caretCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @caretIcon={{hash open="caret-up" closed="caret-down"}}
  @variant="static"
/>`;

  disabledCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @disabled={{true}}
  @variant="static"
/>`;

  readonlyCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @readonly={{true}}
  @variant="static"
/>`;

  minCharsCode = `<DSelect
  @load={{this.loadOptions}}
  @value={{this.value}}
  @resolveValue={{this.resolveOption}}
  @onChange={{this.onChange}}
  @minChars={{3}}
  @clearable={{true}}
/>`;

  placementCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
  @placement="top"
  @offset={{16}}
/>`;

  debounceCode = `<DSelect
  @load={{this.load}}
  @value={{this.value}}
  @resolveValue={{this.resolveValue}}
  @onChange={{this.onChange}}
  @variant="button"
  @debounce={{300}}
  @placement="top-start"
/>`;

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
  @resolveValue={{this.resolveLocale}}
  @onChange={{this.onChange}}
  @variant="button"
/>`;

  // Identity counter for the debounce dispatch log; see `loadDebounced`.
  #debounceSeq = 0;

  get groups() {
    return GROUPS.map((id) => ({
      id,
      title: i18n(`styleguide.sections.select.groups.${id}.title`),
      description: i18n(`styleguide.sections.select.groups.${id}.description`),
    }));
  }

  get notificationLevels() {
    return notificationLevels();
  }

  // The consumer owns @value, so it owns the glyph too: the component never derives one. This is
  // the counterpart to the fixed globe beside it, where the icon names the FIELD rather than the
  // value and correctly never changes.
  get iconFollowsIcon() {
    return (
      this.notificationLevels.find(
        (level) => level.level === this.iconFollowsValue
      )?.icon ?? "bell"
    );
  }

  get iconOnlyIcon() {
    return (
      this.notificationLevels.find(
        (level) => level.level === this.iconOnlyValue
      )?.icon ?? "bell"
    );
  }

  // Far more than a single virtualized window, so scrolling to the true last row is
  // exercised both by hand and by a system spec.
  get largeListItems() {
    return topics();
  }

  filterItems(items, filter) {
    const normalizedFilter = filter.toLowerCase();
    return items.filter((item) =>
      item.name.toLowerCase().includes(normalizedFilter)
    );
  }

  @action
  async loadEmpty(_filter, { signal }) {
    await delay(signal);
    return [];
  }

  // Deliberately over the four-row set: a bare array asserts completeness, and the spec that
  // guards against the engine probing for a second page counts exactly four rows.
  @action
  async loadOptions(filter, { signal }) {
    await delay(signal, ASYNC_BUTTON_DELAY);
    return this.filterItems(this.fourOptions, filter);
  }

  @action
  async loadLocales(filter, { signal }) {
    await delay(signal, ASYNC_BUTTON_DELAY);
    return this.filterItems(this.items, filter);
  }

  @action
  async loadWithRetry(filter, { signal }) {
    await delay(signal);
    this.errorRequestCount++;

    if (this.errorRequestCount === 1) {
      throw new Error(i18n("styleguide.sections.select.request_error"));
    }

    return this.filterItems(this.items, filter);
  }

  // Every async example pairs its loader with one of these. A loader answers "what matches this
  // query"; a resolver answers "what is this id", which is a different question against
  // different data — here a lookup in the same fixture, standing in for the store lookup a real
  // consumer would do. Without one, a select that reopens holding a value can only show it as
  // unavailable, since nothing it has been given can turn the id back into a row.
  //
  // They return synchronously on purpose: a resolver does not have to be async, and one that
  // answers from data already in hand costs no request.
  // Counts what the reader typed, against what the component actually sent. `input` bubbles out
  // of the query input to the trigger root, which is where `...attributes` land, so the card can
  // observe typing without the component exposing a keystroke hook.
  @action
  countDebounceKeystroke() {
    this.debounceKeystrokes++;
  }

  // A real source rather than a client array: the point of the card is which queries were
  // DISPATCHED, and a client filter dispatches nothing to observe. Each call appends the query
  // it was given, so the gap between keystrokes and entries IS the debounce.
  @action
  async loadDebounced(filter, { signal }) {
    await delay(signal, 250);
    // Each entry gets its own id: the same query can legitimately be dispatched twice, so the
    // text is not an identity, and the log is reset as well as appended to.
    this.debounceQueries = [
      ...this.debounceQueries,
      { id: (this.#debounceSeq += 1), query: filter },
    ];
    return this.filterItems(this.items, filter);
  }

  @action
  resetDebounceLog() {
    this.debounceKeystrokes = 0;
    this.debounceQueries = [];
  }

  // The failure IS the card, so it has to be reachable more than once. Without this the source
  // succeeds for the rest of the page's life after the first retry, and a reader who closes the
  // panel before reading it finds a card demonstrating nothing.
  @action
  resetErrorSource() {
    this.errorRequestCount = 0;
  }

  @action
  resolveLocale(value) {
    return this.items.find((item) => item.id === value);
  }

  @action
  resolveOption(value) {
    return this.fourOptions.find((item) => item.id === value);
  }

  @action
  resolveTopic(value) {
    return this.largeListItems.find((item) => item.id === value);
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
  async loadPage(filter, { signal, offset = 0, limit = PAGE_SIZE }) {
    await delay(signal, 900);
    const matches = this.largeListItems.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
    return {
      items: matches.slice(offset, offset + limit),
      total: matches.length,
    };
  }

  // Answers inside the loading-feedback threshold, so a re-query keeps the previous rows and
  // never drops to a skeleton. Paired with `loadPage` (900ms), which sits well outside it.
  @action
  async loadPageFast(filter, { signal, offset = 0, limit = PAGE_SIZE }) {
    await delay(signal, 120);
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
  updateFastReload(value) {
    this.fastReloadValue = value;
  }

  @action
  updateSlowReload(value) {
    this.slowReloadValue = value;
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
  updateToggle(value) {
    this.toggleValue = value;
  }

  @action
  updateNone(value) {
    this.noneValue = value;
  }

  @action
  updateIconOnly(value) {
    this.iconOnlyValue = value;
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
  updateIconFollows(value) {
    this.iconFollowsValue = value;
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

    <SelectAriaProbe />

    <SelectHero />

    <StyleguideGroups
      @groups={{this.groups}}
      @section={{@section}}
      @active={{@group}}
      @ariaLabel={{i18n "styleguide.sections.select.groups.aria_label"}}
      as |Group|
    >
      <Group @id="start">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.default_example"}}
          @description={{i18n "styleguide.sections.select.default_description"}}
          @tryThis={{i18n "styleguide.sections.select.default_try_this"}}
          @code={{this.defaultCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-default"
              @items={{this.fourOptions}}
              @value={{this.defaultValue}}
              @onChange={{this.updateDefault}}
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.static_example"}}
          @description={{i18n "styleguide.sections.select.static_description"}}
          @tryThis={{i18n "styleguide.sections.select.static_try_this"}}
          @code={{this.staticCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-static"
              @items={{this.items}}
              @value={{this.staticValue}}
              @onChange={{this.updateStatic}}
              @variant="static"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.multi_example"}}
          @description={{i18n "styleguide.sections.select.multi_description"}}
          @tryThis={{i18n "styleguide.sections.select.multi_try_this"}}
          @code={{this.multiCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-multi"
              @items={{this.fourOptions}}
              @multiple={{true}}
              @value={{this.multiValue}}
              @onChange={{this.updateMulti}}
              @placeholder={{i18n
                "styleguide.sections.select.multi_placeholder"
              }}
            />
          </div>
        </StyleguideExample>
      </Group>

      <Group @id="data">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.min_chars_example"}}
          @description={{i18n
            "styleguide.sections.select.min_chars_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.min_chars_try_this"}}
          @code={{this.minCharsCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-min-chars"
              @load={{this.loadLocales}}
              @resolveValue={{this.resolveLocale}}
              @value={{this.minCharsValue}}
              @onChange={{this.updateMinChars}}
              @minChars={{3}}
              @clearable={{true}}
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.debounce_example"}}
          @description={{i18n
            "styleguide.sections.select.debounce_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.debounce_try_this"}}
          @code={{this.debounceCode}}
        >
          <:default>
            <div class="select-examples__control">
              <DSelect
                @identifier="sg-debounce"
                {{! Opens upward: the dispatch tally sits below the control, and it is what the
                reader is meant to watch WHILE typing, so a downward panel would cover it. }}
                @placement="top-start"
                @load={{this.loadDebounced}}
                @resolveValue={{this.resolveLocale}}
                @value={{this.debounceValue}}
                @onChange={{this.updateDebounce}}
                @onShow={{this.resetDebounceLog}}
                @variant="button"
                @debounce={{300}}
                @placeholder={{i18n "styleguide.sections.select.placeholder"}}
                {{on "input" this.countDebounceKeystroke}}
              />
            </div>
          </:default>

          <:result>
            {{i18n
              "styleguide.sections.select.debounce_result"
              keystrokes=this.debounceKeystrokes
              requests=this.debounceQueries.length
            }}
            {{#if this.debounceQueries}}
              <ol class="select-examples__query-log">
                {{#each this.debounceQueries key="id" as |entry|}}
                  <li>&ldquo;{{entry.query}}&rdquo;</li>
                {{/each}}
              </ol>
            {{/if}}
          </:result>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.paged_example"}}
          @description={{i18n "styleguide.sections.select.paged_description"}}
          @tryThis={{i18n "styleguide.sections.select.paged_try_this"}}
          @code={{this.pagedCode}}
        >
          <:default>
            <div class="select-examples__control">
              <DSelect
                @identifier="sg-paged"
                @load={{this.loadPage}}
                @resolveValue={{this.resolveTopic}}
                @value={{this.pagedValue}}
                @onChange={{this.updatePaged}}
                @placeholder={{i18n "styleguide.sections.select.placeholder"}}
              />
            </div>

          </:default>
          <:note>{{i18n "styleguide.sections.select.paged_note"}}</:note>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.paged_cursor_example"}}
          @description={{i18n
            "styleguide.sections.select.paged_cursor_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.paged_cursor_try_this"}}
          @code={{this.pagedCode}}
        >
          <:default>
            <div class="select-examples__control">
              <DSelect
                @identifier="sg-paged-cursor"
                @load={{this.loadPageCursor}}
                @resolveValue={{this.resolveTopic}}
                @value={{this.pagedCursorValue}}
                @onChange={{this.updatePagedCursor}}
                @placeholder={{i18n "styleguide.sections.select.placeholder"}}
              />
            </div>

          </:default>
          <:note>{{i18n "styleguide.sections.select.paged_cursor_note"}}</:note>
        </StyleguideExample>
      </Group>

      <Group @id="states">
        <StyleguideExample
          class="--wide"
          @title={{i18n "styleguide.sections.select.reload_example"}}
          @description={{i18n "styleguide.sections.select.reload_description"}}
          @tryThis={{i18n "styleguide.sections.select.reload_try_this"}}
          @code={{this.reloadCode}}
        >
          <div class="select-examples__pair">
            <div class="select-examples__pair-item">
              <p class="select-examples__pair-label">
                {{i18n "styleguide.sections.select.reload_fast_label"}}
              </p>
              <div class="select-examples__control">
                <DSelect
                  @identifier="sg-reload-fast"
                  @load={{this.loadPageFast}}
                  @resolveValue={{this.resolveTopic}}
                  @value={{this.fastReloadValue}}
                  @onChange={{this.updateFastReload}}
                  @placeholder={{i18n "styleguide.sections.select.placeholder"}}
                />
              </div>
            </div>
            <div class="select-examples__pair-item">
              <p class="select-examples__pair-label">
                {{i18n "styleguide.sections.select.reload_slow_label"}}
              </p>
              <div class="select-examples__control">
                <DSelect
                  @identifier="sg-reload-slow"
                  @load={{this.loadPage}}
                  @resolveValue={{this.resolveTopic}}
                  @value={{this.slowReloadValue}}
                  @onChange={{this.updateSlowReload}}
                  @placeholder={{i18n "styleguide.sections.select.placeholder"}}
                />
              </div>
            </div>
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.async_button_example"}}
          @description={{i18n
            "styleguide.sections.select.async_button_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.async_button_try_this"}}
          @code={{this.asyncButtonCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-async-button"
              @load={{this.loadOptions}}
              @resolveValue={{this.resolveOption}}
              @value={{this.asyncButtonValue}}
              @onChange={{this.updateAsyncButton}}
              @variant="button"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.empty_example"}}
          @description={{i18n "styleguide.sections.select.empty_description"}}
          @tryThis={{i18n "styleguide.sections.select.empty_try_this"}}
          @code={{this.emptyCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-empty"
              @load={{this.loadEmpty}}
              @value={{this.emptyValue}}
              @onChange={{this.updateEmpty}}
              @variant="button"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
              @noResultsLabel={{i18n "styleguide.sections.select.empty_label"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.error_example"}}
          @description={{i18n "styleguide.sections.select.error_description"}}
          @tryThis={{i18n "styleguide.sections.select.error_try_this"}}
          @code={{this.errorCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-error"
              @load={{this.loadWithRetry}}
              @onClose={{this.resetErrorSource}}
              @resolveValue={{this.resolveLocale}}
              @value={{this.errorValue}}
              @onChange={{this.updateError}}
              @variant="button"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
      </Group>

      <Group @id="appearance">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.icon_example"}}
          @description={{i18n "styleguide.sections.select.icon_description"}}
          @tryThis={{i18n "styleguide.sections.select.icon_try_this"}}
          @code={{this.iconCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-icon"
              @items={{this.items}}
              @value={{this.iconValue}}
              @onChange={{this.updateIcon}}
              @icon="globe"
              @variant="static"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.icon_follows_example"}}
          @description={{i18n
            "styleguide.sections.select.icon_follows_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.icon_follows_try_this"}}
          @code={{this.iconFollowsCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-icon-follows"
              @items={{this.notificationLevels}}
              @value={{this.iconFollowsValue}}
              @onChange={{this.updateIconFollows}}
              @valueField="level"
              @labelField="title"
              @icon={{this.iconFollowsIcon}}
              @variant="static"
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.icon_only_example"}}
          @description={{i18n
            "styleguide.sections.select.icon_only_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.icon_only_try_this"}}
          @code={{this.iconOnlyCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-icon-only"
              @items={{this.notificationLevels}}
              @variant="static"
              @value={{this.iconOnlyValue}}
              @onChange={{this.updateIconOnly}}
              @valueField="level"
              @labelField="title"
              @icon={{this.iconOnlyIcon}}
              @iconOnly={{true}}
              @label={{i18n "styleguide.sections.select.icon_only_label"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.caret_example"}}
          @description={{i18n "styleguide.sections.select.caret_description"}}
          @tryThis={{i18n "styleguide.sections.select.caret_try_this"}}
          @code={{this.caretCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-caret"
              @items={{this.items}}
              @value={{this.caretValue}}
              @onChange={{this.updateCaret}}
              @caretIcon={{hash open="caret-up" closed="caret-down"}}
              @variant="static"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.placement_example"}}
          @description={{i18n
            "styleguide.sections.select.placement_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.placement_try_this"}}
          @code={{this.placementCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-placement"
              @items={{this.items}}
              @value={{this.placementValue}}
              @onChange={{this.updatePlacement}}
              @variant="button"
              @placement="top"
              @offset={{16}}
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.events_example"}}
          @description={{i18n "styleguide.sections.select.events_description"}}
          @tryThis={{i18n "styleguide.sections.select.events_try_this"}}
          @code={{this.eventsCode}}
        >
          <:default>
            <div class="select-examples__control">
              <DSelect
                @identifier="sg-events"
                {{! Opens upward: the tally below counts opens, so it changes at the exact moment
                a downward panel would cover it. }}
                @placement="top-start"
                @items={{this.items}}
                @value={{this.eventsValue}}
                @onChange={{this.updateEvents}}
                @onShow={{this.onShow}}
                @onClose={{this.onClose}}
                @placeholder={{i18n "styleguide.sections.select.placeholder"}}
              />
            </div>

          </:default>
          <:result>
            {{i18n
              "styleguide.sections.select.events_note"
              opened=this.openCount
              closed=this.closeCount
            }}
          </:result>
        </StyleguideExample>
      </Group>

      <Group @id="content">
        <SelectContent />
      </Group>

      <Group @id="selection">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.maximum_example"}}
          @description={{i18n "styleguide.sections.select.maximum_description"}}
          @tryThis={{i18n "styleguide.sections.select.maximum_try_this"}}
          @code={{this.maximumCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-maximum"
              @items={{this.items}}
              @multiple={{true}}
              @maximum={{MAXIMUM}}
              @value={{this.maximumValue}}
              @onChange={{this.updateMaximum}}
              @placeholder={{i18n
                "styleguide.sections.select.multi_placeholder"
              }}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.toggle_example"}}
          @description={{i18n "styleguide.sections.select.toggle_description"}}
          @tryThis={{i18n "styleguide.sections.select.toggle_try_this"}}
          @code={{this.toggleCode}}
        >
          <:default>
            <div class="select-examples__control">
              <DSelect
                @identifier="sg-toggle"
                @items={{this.items}}
                @multiple={{true}}
                @variant="button"
                @value={{this.toggleValue}}
                @onChange={{this.updateToggle}}
                @label={{i18n "styleguide.sections.select.toggle_label"}}
                @placeholder={{i18n
                  "styleguide.sections.select.multi_placeholder"
                }}
              />
            </div>
          </:default>
          <:note>{{i18n "styleguide.sections.select.toggle_note"}}</:note>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.none_example"}}
          @description={{i18n "styleguide.sections.select.none_description"}}
          @tryThis={{i18n "styleguide.sections.select.none_try_this"}}
          @code={{this.noneCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-none"
              @items={{this.items}}
              @value={{this.noneValue}}
              @onChange={{this.updateNone}}
              @noneLabel={{i18n "styleguide.sections.select.none_label"}}
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.clearable_example"}}
          @description={{i18n
            "styleguide.sections.select.clearable_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.clearable_try_this"}}
          @code={{this.clearableCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-clearable"
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
          @description={{i18n
            "styleguide.sections.select.clearable_multi_description"
          }}
          @tryThis={{i18n
            "styleguide.sections.select.clearable_multi_try_this"
          }}
          @code={{this.clearableMultiCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-clearable-multi"
              @items={{this.items}}
              @multiple={{true}}
              @value={{this.clearableMultiValue}}
              @onChange={{this.updateClearableMulti}}
              @clearable={{true}}
              @placeholder={{i18n
                "styleguide.sections.select.multi_placeholder"
              }}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.disabled_example"}}
          @description={{i18n
            "styleguide.sections.select.disabled_description"
          }}
          @code={{this.disabledCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-disabled"
              @items={{this.items}}
              @value={{this.disabledValue}}
              @onChange={{this.updateDisabled}}
              @disabled={{true}}
              @variant="static"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.readonly_example"}}
          @description={{i18n
            "styleguide.sections.select.readonly_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.readonly_try_this"}}
          @code={{this.readonlyCode}}
        >
          <div class="select-examples__control">
            <DSelect
              @identifier="sg-readonly"
              @items={{this.items}}
              @value={{this.readonlyValue}}
              @onChange={{this.updateReadonly}}
              @readonly={{true}}
              @variant="static"
              @placeholder={{i18n "styleguide.sections.select.placeholder"}}
            />
          </div>
        </StyleguideExample>
      </Group>

      <Group @id="keyboard">
        <SelectKeyboard />
      </Group>

      <Group @id="limits">
        <StyleguideExample
          @title={{i18n "styleguide.sections.select.large_list_example"}}
          @description={{i18n
            "styleguide.sections.select.large_list_description"
          }}
          @tryThis={{i18n "styleguide.sections.select.large_list_try_this"}}
          @code={{this.largeListCode}}
        >
          <:default>
            <div class="select-examples__control">
              <DSelect
                @identifier="sg-large-list"
                @items={{this.largeListItems}}
                @value={{this.largeListValue}}
                @onChange={{this.updateLargeList}}
                @placeholder={{i18n "styleguide.sections.select.placeholder"}}
              />
            </div>

          </:default>
          <:note>{{i18n "styleguide.sections.select.large_list_note"}}</:note>
        </StyleguideExample>
      </Group>

      <Group @id="pickers">
        <SelectShowcases />
      </Group>
    </StyleguideGroups>
  </template>
}
