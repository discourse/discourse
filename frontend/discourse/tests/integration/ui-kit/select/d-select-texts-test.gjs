import { tracked } from "@glimmer/tracking";
import { registerWarnHandler } from "@ember/debug";
import {
  click,
  fillIn,
  find,
  findAll,
  getSettledState,
  render,
  rerender,
  resetOnerror,
  settled,
  setupOnerror,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { ITEMS, optionWithText } from "discourse/tests/helpers/d-select-hosts";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import {
  DEFAULT_SELECT_TEXTS,
  renderSelectText,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const REQUIRED = new Set([
  "ariaLabel",
  "clear",
  "clearAll",
  "retry",
  "removeItem",
  "chipsLabel",
  "stripLabel",
  "footerLabel",
  "labelWithValue",
  "labelWithCount",
  "unresolvedValue",
  "createItem",
  "removeHint",
  "loadError",
  "noneLabel",
  "loadingLabel",
]);

const warningSink = tracked(undefined);

registerWarnHandler((message, options, next) => {
  if (
    warningSink.value &&
    options?.id?.startsWith("discourse.d-select.texts-")
  ) {
    warningSink.value(message, options);
  } else {
    next(message, options);
  }
});

function customize(register) {
  withPluginApi((api) =>
    api.registerValueTransformer("select-customizations", ({ value }) =>
      register(value)
    )
  );
}

function forIdentifier(texts) {
  customize((selects) =>
    selects.forIdentifier("texts-test", (spec) =>
      spec.options(() => ({ texts }))
    )
  );
}

/** All mutable arguments belong to a controlled consumer, rather than a probe component. */
async function mount(configuration = {}) {
  if (configuration.mobile) {
    forceMobile();
  }
  const Select = configuration.list ? DSelectList : DSelect;
  const state = tracked({
    items: ITEMS,
    kind: "texts-kind",
    value: configuration.multiple || configuration.list ? [] : null,
    suppressFooter: !configuration.footer,
    ...configuration,
  });
  const onChange = (value) => {
    state.value.onChange?.(value);
    state.value = { ...state.value, value };
  };
  await render(
    <template>
      <span id="texts-caption">Fruit caption</span>
      <span id="texts-description">Consumer description</span>
      {{#if state.value.scrolling}}
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .texts-test-content .d-virtual-list {
            height: 160px;
            overflow-y: auto;
          }
        </style>
      {{/if}}
      <Select
        @allowCreate={{state.value.allowCreate}}
        @ariaLabelledBy={{state.value.labelledBy}}
        @clearable={{state.value.clearable}}
        @createItem={{state.value.createItem}}
        @debounce={{false}}
        @describedBy={{state.value.describedBy}}
        @disabled={{state.value.disabled}}
        @hideSelected={{state.value.hideSelected}}
        @identifier="texts-test"
        @items={{state.value.items}}
        @kind={{state.value.kind}}
        @kindTexts={{state.value.kindTexts}}
        @kindTextWrappers={{state.value.wrappers}}
        @load={{state.value.load}}
        @loadingStatus={{state.value.loadingStatus}}
        @maximum={{state.value.maximum}}
        @maxLoaded={{state.value.maxLoaded}}
        @maxVisibleChips={{state.value.maxVisibleChips}}
        @minChars={{state.value.minChars}}
        @minimum={{state.value.minimum}}
        @multiple={{state.value.multiple}}
        @noneRow={{state.value.noneRow}}
        @onChange={{onChange}}
        @panelChips={{state.value.panelChips}}
        @readonly={{state.value.readonly}}
        @resolveValue={{state.value.resolveValue}}
        @suppressFooter={{state.value.suppressFooter}}
        @texts={{state.value.texts}}
        @value={{state.value.value}}
        @variant={{state.value.variant}}
        @virtualized={{state.value.virtualized}}
      >
        <:footer><span>Consumer action</span></:footer>
      </Select>
    </template>
  );
  return state;
}

function gate() {
  const release = tracked(undefined);
  const promise = new Promise((resolve) => (release.value = resolve));
  return { promise, resolve: (value) => release.value(value) };
}

function press(key, selector = "input[role='combobox']") {
  find(selector).dispatchEvent(
    new KeyboardEvent("keydown", { key, bubbles: true })
  );
}

function typeNow(value, selector = "input[role='combobox']") {
  const input = find(selector);
  input.value = value;
  input.dispatchEvent(new Event("input", { bubbles: true }));
}

async function expectAssertion(assert, action, pattern) {
  const errors = tracked([]);
  const record = (error) => (errors.value = [...errors.value, error]);
  setupOnerror(record);
  try {
    await action();
  } catch (error) {
    record(error);
  } finally {
    resetOnerror();
  }
  assert.true(
    errors.value.some(
      (error) =>
        /Assertion Failed/i.test(error.message) && pattern.test(error.message)
    ),
    `an Ember assertion identifies ${pattern}: ${errors.value.map((error) => error.message).join("; ")}`
  );
}

const SCENARIOS = {
  input: {},
  button: { variant: "button" },
  static: { variant: "static" },
  mobile: { mobile: true },
  multiInput: { multiple: true },
  multiButton: { multiple: true, variant: "button" },
  multiStatic: { multiple: true, variant: "static" },
  multiMobile: { multiple: true, mobile: true },
  held: { multiple: true, value: [1] },
  compact: { multiple: true, value: [1, 2], maxVisibleChips: 0 },
  heldCompact: { multiple: true, value: [1], maxVisibleChips: 0 },
  overflow: { multiple: true, value: [1, 2, 3], maxVisibleChips: 1 },
  heldButton: {
    multiple: true,
    value: [1],
    variant: "button",
    panelChips: true,
  },
  heldStatic: {
    multiple: true,
    value: [1],
    variant: "static",
    hideSelected: true,
  },
  heldMobile: { multiple: true, value: [1], mobile: true },
  mobileButton: { multiple: true, value: [1], variant: "button", mobile: true },
  valueButton: { value: 1, variant: "button" },
  valueStatic: { value: 1, variant: "static" },
  valueMobile: { value: 1, mobile: true },
  countButton: {
    multiple: true,
    value: [1, 2],
    maxVisibleChips: 0,
    variant: "button",
  },
  countMobile: {
    multiple: true,
    value: [1, 2],
    maxVisibleChips: 0,
    mobile: true,
  },
  captionCount: {
    multiple: true,
    value: [1, 2],
    maxVisibleChips: 0,
    labelledBy: "texts-caption",
  },
  list: { list: true },
  heldList: { list: true, value: [1] },
  descriptionInput: { describedBy: "texts-description" },
  descriptionMobile: {
    multiple: true,
    mobile: true,
    describedBy: "texts-description",
  },
  descriptionHeld: {
    multiple: true,
    value: [1],
    describedBy: "texts-description",
  },
  descriptionHeldMobile: {
    multiple: true,
    value: [1],
    mobile: true,
    describedBy: "texts-description",
  },
  descriptionSearch: { mobile: true, describedBy: "texts-description" },
  staticList: { list: true, virtualized: false },
  none: { noneRow: true },
  footer: { footer: true },
  minChars: { minChars: 3 },
  maximum: { multiple: true, value: [1, 2], maximum: 2 },
  minimum: { multiple: true, value: [1], minimum: 3 },
  clear: { value: 1, clearable: true },
  clearAll: { multiple: true, value: [1, 2], clearable: true },
  unresolvedInput: { items: [], value: 404, resolveValue: () => undefined },
  unresolvedChip: {
    items: [],
    multiple: true,
    value: [404],
    resolveValue: () => undefined,
  },
  unresolvedStrip: {
    items: [],
    multiple: true,
    value: [404],
    maxVisibleChips: 0,
    resolveValue: () => undefined,
  },
  create: { allowCreate: true, createItem: (name) => ({ id: name, name }) },
  error: { load: () => Promise.reject(new Error("load failed")) },
  maxLoaded: { load: () => ({ items: ITEMS, total: 30 }), maxLoaded: 3 },
  resultsCount: { variant: "button" },
  resultsLoaded: {
    variant: "button",
    load: () => ({ items: ITEMS, hasMore: true }),
  },
};

function drawn(key, place, scenario, selector, extra = {}) {
  return { key, place, scenario, selector, ...extra };
}

function attr(key, place, scenario, selector, attribute, extra = {}) {
  return drawn(key, place, scenario, selector, { attribute, ...extra });
}

function spoken(key, place, scenario, extra = {}) {
  return { key, place, scenario, announcement: true, ...extra };
}

/** Rows are uses, not keys: each host and each drawn/spoken form gets its own row. */
const USES = [
  attr(
    "searchPlaceholder",
    "mobile button multi panel",
    "mobileButton",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "ariaLabel",
    "multiple desktop input",
    "multiInput",
    ".d-select__input",
    "aria-label"
  ),
  attr(
    "ariaLabel",
    "multiple button chip panel input",
    "heldButton",
    ".d-select__filter",
    "aria-label",
    { open: true }
  ),
  attr(
    "ariaLabel",
    "multiple mobile modal input",
    "multiMobile",
    ".d-select__filter",
    "aria-label",
    { open: true }
  ),
  drawn(
    "placeholder",
    "desktop hidden description",
    "descriptionInput",
    ".d-select__input",
    { description: true }
  ),
  drawn(
    "placeholder",
    "mobile hidden description",
    "descriptionMobile",
    ".d-select__filter",
    { description: true, open: true }
  ),
  drawn(
    "addMorePlaceholder",
    "desktop hidden description",
    "descriptionHeld",
    ".d-select__input",
    { description: true }
  ),
  drawn(
    "addMorePlaceholder",
    "mobile hidden description",
    "descriptionHeldMobile",
    ".d-select__filter",
    { description: true, open: true }
  ),
  drawn(
    "searchPlaceholder",
    "mobile hidden description",
    "descriptionSearch",
    ".d-select__filter",
    { description: true, open: true }
  ),
  attr(
    "placeholder",
    "single input",
    "input",
    ".d-select__input",
    "placeholder"
  ),
  drawn("placeholder", "single button", "button", ".d-select__placeholder"),
  drawn("placeholder", "single static", "static", ".d-select__placeholder"),
  drawn(
    "placeholder",
    "single mobile trigger",
    "mobile",
    ".d-select__trigger .d-select__placeholder"
  ),
  attr(
    "placeholder",
    "multiple input",
    "multiInput",
    ".d-select__input",
    "placeholder"
  ),
  drawn(
    "placeholder",
    "multiple button",
    "multiButton",
    ".d-select__placeholder"
  ),
  drawn(
    "placeholder",
    "multiple static",
    "multiStatic",
    ".d-select__placeholder"
  ),
  drawn(
    "placeholder",
    "multiple mobile trigger",
    "multiMobile",
    ".d-select__trigger .d-select__placeholder"
  ),
  attr(
    "placeholder",
    "multiple mobile modal input",
    "multiMobile",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "addMorePlaceholder",
    "held desktop input",
    "held",
    ".d-select__input",
    "placeholder"
  ),
  attr(
    "addMorePlaceholder",
    "compact desktop input",
    "compact",
    ".d-select__input",
    "placeholder"
  ),
  attr(
    "addMorePlaceholder",
    "held mobile modal input",
    "heldMobile",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "searchPlaceholder",
    "single button panel",
    "button",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "searchPlaceholder",
    "multiple button panel",
    "multiButton",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "searchPlaceholder",
    "multiple button chip panel",
    "heldButton",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "searchPlaceholder",
    "single mobile modal",
    "mobile",
    ".d-select__filter",
    "placeholder",
    { open: true }
  ),
  attr(
    "searchPlaceholder",
    "persistent list input",
    "list",
    ".d-select__filter",
    "placeholder"
  ),
  drawn("noResults", "empty state", "input", ".d-select__empty", {
    action: "empty",
    keepEmpty: true,
  }),
  spoken("noResults", "empty announcement", "input", { action: "empty" }),
  attr("ariaLabel", "desktop input", "input", ".d-select__input", "aria-label"),
  attr(
    "ariaLabel",
    "button trigger",
    "button",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "ariaLabel",
    "static trigger",
    "static",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "ariaLabel",
    "mobile trigger",
    "mobile",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "ariaLabel",
    "windowed listbox",
    "input",
    "[role='listbox']",
    "aria-label",
    { open: true }
  ),
  attr(
    "ariaLabel",
    "static listbox",
    "static",
    "[role='listbox']",
    "aria-label",
    { open: true }
  ),
  attr(
    "ariaLabel",
    "button panel input",
    "button",
    ".d-select__filter",
    "aria-label",
    { open: true }
  ),
  attr("ariaLabel", "mobile modal", "mobile", "[role='dialog']", "aria-label", {
    open: true,
  }),
  attr(
    "ariaLabel",
    "mobile modal input",
    "mobile",
    ".d-select__filter",
    "aria-label",
    { open: true }
  ),
  attr(
    "ariaLabel",
    "persistent list input",
    "list",
    ".d-select__filter",
    "aria-label"
  ),
  attr(
    "ariaLabel",
    "persistent listbox",
    "list",
    "[role='listbox']",
    "aria-label"
  ),
  attr(
    "ariaLabel",
    "persistent static listbox",
    "staticList",
    "[role='listbox']",
    "aria-label"
  ),
  attr(
    "labelWithValue",
    "button value name",
    "valueButton",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "labelWithValue",
    "static value name",
    "valueStatic",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "labelWithValue",
    "mobile value name",
    "valueMobile",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "labelWithCount",
    "compact input name",
    "compact",
    ".d-select__input",
    "aria-label"
  ),
  attr(
    "labelWithCount",
    "button count name",
    "countButton",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "labelWithCount",
    "mobile count name",
    "countMobile",
    ".d-select__trigger",
    "aria-label"
  ),
  attr(
    "footerLabel",
    "footer group",
    "footer",
    ".d-select__footer",
    "aria-label",
    { open: true }
  ),
  attr(
    "clear",
    "single clear button",
    "clear",
    ".d-select__clear",
    "aria-label"
  ),
  attr(
    "clearAll",
    "multiple clear button",
    "clearAll",
    ".d-select__clear",
    "aria-label"
  ),
  spoken("selectionCleared", "single clear announcement", "clear", {
    action: "clear",
  }),
  spoken("selectionCleared", "multiple clear announcement", "clearAll", {
    action: "clear",
  }),
  drawn("minChars", "typing hint", "minChars", ".d-select__min-chars", {
    open: true,
  }),
  spoken("minChars", "typing announcement", "minChars", { open: true }),
  drawn("maximum", "limit line", "maximum", ".d-select__limit", {
    open: true,
    limit: true,
  }),
  spoken("maximum", "limit announcement", "maximum", { open: true }),
  drawn("minimum", "limit line", "minimum", ".d-select__limit", {
    open: true,
    limit: true,
  }),
  spoken("minimum", "limit announcement", "minimum", { open: true }),
  drawn(
    "removeHint",
    "desktop chip hint",
    "held",
    ".d-select__chip-remove .sr-only"
  ),
  drawn(
    "removeHint",
    "selection strip hint",
    "compact",
    ".d-select__strip-remove .sr-only",
    { open: true }
  ),
  attr(
    "chipsLabel",
    "trigger chip group",
    "held",
    ".d-select__trigger .d-select__chip-list",
    "aria-label"
  ),
  attr(
    "chipsLabel",
    "modal chip group",
    "heldMobile",
    ".d-select__panel .d-select__chip-list",
    "aria-label",
    { open: true }
  ),
  attr(
    "chipsLabel",
    "persistent chip group",
    "heldList",
    ".d-select__chip-list",
    "aria-label"
  ),
  attr(
    "stripLabel",
    "selection strip",
    "compact",
    ".d-select__strip",
    "aria-label",
    { open: true }
  ),
  attr(
    "removeItem",
    "touch chip remove button",
    "held",
    ".d-select__chip-remove",
    "aria-label",
    { touch: true }
  ),
  attr(
    "removeItem",
    "touch strip remove button",
    "heldCompact",
    ".d-select__strip-remove",
    "aria-label",
    { touch: true, open: true }
  ),
  drawn(
    "chipsHint",
    "interactive input hint",
    "held",
    ".d-select__chips > .sr-only[id^='d-select-chip-hint-']",
    { hint: true }
  ),
  drawn(
    "chipsHint",
    "modal input hint",
    "heldMobile",
    ".d-select__panel .d-select__chips > .sr-only[id^='d-select-chip-hint-']",
    { hint: true, open: true }
  ),
  drawn(
    "chipsHint",
    "persistent input hint",
    "heldList",
    ".d-select__chips > .sr-only[id^='d-select-chip-hint-']",
    { hint: true }
  ),
  drawn(
    "selectedItemsHint",
    "display-only input hint",
    "compact",
    ".d-select__chips > .sr-only[id^='d-select-chip-hint-']",
    { hint: true }
  ),
  drawn(
    "selectedCount",
    "trigger summary",
    "heldButton",
    ".d-select__chips-summary",
    { open: true }
  ),
  drawn(
    "selectedCount",
    "caption count name",
    "captionCount",
    "span[id$='-labelled-value']",
    { labelledValue: true }
  ),
  spoken("updatingSelection", "pending update announcement", "update"),
  spoken("itemSelected", "programmatic selection announcement", "select"),
  spoken("itemAdded", "addition announcement", "held", { action: "add" }),
  spoken("itemsAdded", "bulk addition", "bulk"),
  spoken("itemsNotAddedHeld", "bulk held part", "bulk"),
  spoken("itemsNotAddedLimit", "bulk limit part", "bulk"),
  spoken("bulkAddSummary", "bulk composed announcement", "bulk"),
  spoken("allAlreadySelected", "held-only bulk announcement", "already"),
  spoken("itemRemoved", "chip removal announcement", "held", {
    action: "remove",
  }),
  drawn("loadError", "error message", "error", ".d-select__error-message", {
    open: true,
  }),
  drawn("retry", "retry button", "error", ".d-select__retry", { open: true }),
  attr(
    "unresolvedValue",
    "unresolved input value",
    "unresolvedInput",
    ".d-select__input",
    "value",
    { property: true }
  ),
  drawn(
    "unresolvedValue",
    "unresolved chip label",
    "unresolvedChip",
    ".d-select__chip .d-select__unresolved"
  ),
  drawn(
    "unresolvedValue",
    "unresolved strip label",
    "unresolvedStrip",
    ".d-select__strip .d-select__unresolved",
    { open: true }
  ),
  spoken("resultsCount", "known result count", "resultsCount", { open: true }),
  spoken("resultsLoaded", "partial result count", "resultsLoaded", {
    open: true,
  }),
  drawn("maxLoaded", "narrowing hint", "maxLoaded", ".d-select__narrow", {
    open: true,
  }),
  spoken("maxLoaded", "narrowing announcement", "maxLoaded", { open: true }),
  spoken("stillLoading", "pending Enter announcement", "stillLoading"),
  spoken("loadingMore", "page loading announcement", "reveal"),
  spoken("loadingComplete", "page completion announcement", "reveal"),
  drawn("createItem", "create row", "create", "[role='option'].--create", {
    action: "create",
  }),
  drawn("compactCount", "bare chip count", "compact", ".d-select__chips-more"),
  drawn("moreChips", "overflow badge", "overflow", ".d-select__chips-more"),
  drawn("noneLabel", "none row", "none", "[role='option'][data-value='']", {
    open: true,
  }),
  drawn(
    "loadingLabel",
    "loading status",
    "loading",
    ".d-select__loading-status"
  ),
  drawn(
    "loadingLabel",
    "persistent list loading status",
    "loadingList",
    ".d-select__loading-status"
  ),
];

/** Drives one public use, including held requests whose assertions must run before settledness. */
async function drive(row, configuration, observe) {
  if (row.scenario === "loadingList") {
    const pending = gate();
    const mounting = mount({
      ...configuration,
      list: true,
      load: () => pending.promise,
      loadingStatus: true,
    });
    try {
      await waitFor(".d-select__skeleton");
      await observe();
    } finally {
      pending.resolve(ITEMS);
      await mounting;
    }
    return;
  }
  if (["loading", "stillLoading"].includes(row.scenario)) {
    const pending = gate();
    await mount({
      ...configuration,
      load: () => pending.promise,
      loadingStatus: row.scenario === "loading",
    });
    const opening = click(".d-select__trigger");
    try {
      await waitFor(".d-select__skeleton");
      if (row.scenario === "stillLoading") {
        press("Enter");
      }
      await rerender();
      await observe();
    } finally {
      pending.resolve(ITEMS);
      await opening;
    }
    return;
  }
  if (row.scenario === "reveal") {
    enableVirtualization();
    const pending = gate();
    const requested = tracked(false);
    const initial = Array.from({ length: 40 }, (_, index) => ({
      id: index + 1,
      name: `Fruit ${index + 1}`,
    }));
    const load = (_query, { offset = 0 }) => {
      if (offset === 0) {
        return Promise.resolve({ items: initial, total: 41 });
      }
      requested.value = true;
      return pending.promise;
    };
    await mount({ ...configuration, load, scrolling: true });
    await click(".d-select__trigger");
    try {
      const viewport = find(".d-virtual-list");
      viewport.scrollTop = viewport.scrollHeight;
      viewport.dispatchEvent(new Event("scroll"));
      await waitUntil(() => requested.value);
      await waitFor(".d-select__skeleton");
      await rerender();
      if (row.key === "loadingMore") {
        await observe();
      }
    } finally {
      pending.resolve({ items: [{ id: 41, name: "Last fruit" }], total: 41 });
      await settled();
    }
    if (row.key === "loadingComplete") {
      await observe();
    }
    return;
  }
  if (["update", "select", "bulk", "already"].includes(row.scenario)) {
    const pending = gate();
    const onSelect = (control) => {
      if (row.scenario === "update") {
        return control.update(() => pending.promise);
      }
      if (row.scenario === "select") {
        return control.select(ITEMS[1]);
      }
      return control.selectMany(
        row.scenario === "already" ? [ITEMS[0]] : ITEMS
      );
    };
    const multiple = ["bulk", "already"].includes(row.scenario);
    await mount({
      ...configuration,
      items: [...ITEMS, { id: "run-action", name: "Run action", onSelect }],
      multiple,
      value: multiple ? [1] : null,
      maximum: row.scenario === "bulk" ? 2 : undefined,
    });
    await click(".d-select__trigger");
    const choosing = click(optionWithText("Run action"));
    try {
      if (row.scenario === "update") {
        await waitFor(".d-select__pending-icon");
        // Drain the feedback timer without waiting for the held update's test waiter.
        await waitUntil(() => {
          const { hasPendingTimers, hasRunLoop, isRenderPending } =
            getSettledState();
          return !hasPendingTimers && !hasRunLoop && !isRenderPending;
        });
      } else {
        await choosing;
      }
      await observe();
    } finally {
      pending.resolve();
      await choosing;
    }
    return;
  }
  const state = await mount({ ...SCENARIOS[row.scenario], ...configuration });
  if (row.open || ["empty", "add", "create"].includes(row.action)) {
    await click(".d-select__trigger");
  }
  if (row.action === "empty" || row.action === "create") {
    await fillIn("input[role='combobox']", "Pear");
  } else if (row.action === "clear") {
    await click(".d-select__clear");
  } else if (row.action === "add") {
    await click(optionWithText("Banana"));
  } else if (row.action === "remove") {
    await click(".d-select__chip-remove");
  }
  await observe(state);
}

function assertUse(assert, row, expected, announce) {
  if (row.description) {
    const ids =
      find(row.selector)
        .getAttribute("aria-describedby")
        ?.split(/\s+/)
        .filter(Boolean) ?? [];
    if (expected === "") {
      assert
        .dom(row.selector)
        .doesNotHaveAttribute(
          "placeholder",
          "the empty placeholder has no attribute"
        );
      assert.true(
        ids.includes("texts-description"),
        "the consumer's description stays"
      );
      for (const id of ids) {
        const element = document.getElementById(id);
        assert.notStrictEqual(
          element?.textContent.trim(),
          "",
          "no empty placeholder description remains"
        );
        const retainedDescription =
          id === "texts-description" || id.startsWith("d-select-chip-hint-");
        assert.true(
          retainedDescription,
          "only the consumer and chip hint remain"
        );
      }
    } else {
      const element = document.getElementById(ids[0]);
      assert
        .dom(element)
        .hasText(
          expected,
          "the first description contains the customized placeholder"
        )
        .hasClass("sr-only", "the duplicate text is visually hidden");
    }
    return;
  }
  if (row.announcement) {
    const messages = announce.getCalls().map((call) => call.args[0]);
    if (expected === "") {
      assert.false(
        messages.some((message) => message.trim() === ""),
        "empty text never reaches a11y.announce"
      );
      const original = {
        noResults: i18n("d_select.no_results"),
        selectionCleared: i18n("d_select.selection_cleared"),
        minChars: i18n("d_select.min_chars", { count: 3 }),
        maximum: i18n("d_select.max_reached", { count: 2 }),
        minimum: i18n("d_select.min_not_reached", { count: 3, selected: 1 }),
        updatingSelection: i18n("d_select.updating_selection"),
        itemSelected: i18n("d_select.item_selected", { item: "Banana" }),
        itemAdded: i18n("d_select.item_added", { item: "Banana" }),
        itemsAdded: i18n("d_select.items_added", { count: 1 }),
        itemsNotAddedHeld: i18n("d_select.items_not_added_held", { count: 1 }),
        itemsNotAddedLimit: i18n("d_select.items_not_added_limit", {
          count: 1,
        }),
        allAlreadySelected: i18n("d_select.all_already_selected"),
        itemRemoved: i18n("d_select.item_removed", { item: "Apple" }),
        resultsCount: i18n("d_select.results_count", { count: 3 }),
        resultsLoaded: i18n("d_select.results_loaded", { count: 3 }),
        maxLoaded: i18n("d_select.filter_to_narrow"),
        stillLoading: i18n("d_select.still_loading"),
        loadingMore: i18n("d_select.loading_more"),
        loadingComplete: i18n("d_select.loading_complete"),
      }[row.key];
      if (original) {
        assert.false(
          messages.some((message) => message.includes(original)),
          "suppressed text does not fall back to the default announcement"
        );
      }
      const bulkParts = {
        itemsAdded: i18n("d_select.items_added", { count: 1 }),
        itemsNotAddedHeld: i18n("d_select.items_not_added_held", { count: 1 }),
        itemsNotAddedLimit: i18n("d_select.items_not_added_limit", {
          count: 1,
        }),
      };
      if (Object.hasOwn(bulkParts, row.key)) {
        for (const [key, part] of Object.entries(bulkParts)) {
          if (key !== row.key) {
            assert.true(
              messages.some((message) => message.includes(part)),
              `${key} still contributes when another bulk part is empty`
            );
          }
        }
      }
      if (row.key === "bulkAddSummary") {
        const parts = [
          i18n("d_select.items_added", { count: 1 }),
          i18n("d_select.items_not_added_held", { count: 1 }),
          i18n("d_select.items_not_added_limit", { count: 1 }),
        ];
        assert.false(
          messages.some((message) =>
            parts.some((part) => message.includes(part))
          ),
          "an empty summary does not announce its unsuppressed parts"
        );
      }
    } else {
      assert.true(
        announce
          .getCalls()
          .some(
            (call) =>
              call.args[0].includes(expected) && call.args[1] === "polite"
          ),
        `${row.place} speaks the customized text politely`
      );
    }
    return;
  }
  if (expected !== "") {
    if (row.property) {
      assert
        .dom(row.selector)
        .hasValue(
          expected,
          "the customized unresolved label is the input value"
        );
    } else if (row.attribute) {
      assert
        .dom(row.selector)
        .hasAttribute(
          row.attribute,
          expected,
          `${row.place} carries the customized attribute`
        );
    } else {
      assert
        .dom(row.selector)
        .hasText(expected, `${row.place} draws the customized text`);
    }
    if (row.hint) {
      const hint = find(row.selector);
      assert.true(
        findAll("input[aria-describedby]").some((input) =>
          input.getAttribute("aria-describedby").split(/\s+/).includes(hint.id)
        ),
        "the input references its non-empty hint"
      );
    }
  } else if (row.keepEmpty) {
    assert
      .dom(row.selector)
      .exists("the no-results bookkeeping element stays")
      .hasText("", "it has no text")
      .doesNotHaveAttribute(
        "role",
        "the empty bookkeeping element has no role"
      );
  } else if (row.attribute) {
    assert
      .dom(row.selector)
      .exists("the input still exists")
      .doesNotHaveAttribute(row.attribute, "the empty attribute is omitted");
  } else {
    assert.dom(row.selector).doesNotExist("the empty text leaves no element");
  }
  if (expected === "" && (row.limit || row.hint || row.labelledValue)) {
    for (const node of findAll("[aria-describedby], [aria-labelledby]")) {
      for (const attribute of ["aria-describedby", "aria-labelledby"]) {
        const ids =
          node.getAttribute(attribute)?.split(/\s+/).filter(Boolean) ?? [];
        assert.true(
          ids.every((id) => document.getElementById(id)),
          `${attribute} has no dangling id after suppression`
        );
      }
    }
  }
  if (expected === "" && (row.limit || row.key === "maxLoaded")) {
    assert
      .dom("[role='option']")
      .exists(
        { count: ITEMS.length },
        "suppressing a panel message leaves the item rows intact"
      );
  }
}

function assertValues(assert, row, calls) {
  assert.true(calls.called, "the engine evaluated the supplied text function");
  const context = calls.lastCall?.args[1];
  const multiple = Boolean(
    SCENARIOS[row.scenario]?.multiple ||
    SCENARIOS[row.scenario]?.list ||
    ["bulk", "already", "loadingList"].includes(row.scenario)
  );
  assert.strictEqual(
    context?.kind,
    "texts-kind",
    "the context includes the kind"
  );
  assert.strictEqual(
    context?.identifier,
    "texts-test",
    "the context includes the identifier"
  );
  assert.strictEqual(
    context?.multiple,
    multiple,
    "the context describes the actual selection mode"
  );
  assert.strictEqual(
    typeof context?.text,
    "function",
    "the context includes the text accessor"
  );
  const values = calls.lastCall?.args[0];
  if (row.key === "addMorePlaceholder") {
    assert.strictEqual(
      values?.selected,
      row.scenario === "compact" ? 2 : 1,
      "selected is the held count"
    );
    assert.false(
      Object.hasOwn(values ?? {}, "maximum"),
      "uncapped prompts omit maximum"
    );
    return;
  }
  if (row.key === "bulkAddSummary") {
    assert.strictEqual(
      typeof values?.added,
      "string",
      "added is the previously composed text"
    );
    assert.strictEqual(
      values?.not_added,
      i18n("d_select.items_not_added_limit", { count: 1 }),
      "the last summary receives the translated limit part"
    );
    assert.deepEqual(
      Object.keys(values ?? {}).sort(),
      ["added", "not_added"],
      "the summary uses the documented placeholder names"
    );
    return;
  }
  const expected =
    {
      labelWithValue: { label: i18n("d_select.label"), value: "Apple" },
      labelWithCount: { label: i18n("d_select.label"), count: 2 },
      minChars: { count: 3 },
      maximum: { count: 2 },
      minimum: { count: 3, selected: 1 },
      removeItem: { item: "Apple" },
      selectedCount: { count: row.scenario === "captionCount" ? 2 : 1 },
      itemSelected: { item: "Banana" },
      itemAdded: { item: "Banana" },
      itemsAdded: { count: 1 },
      itemsNotAddedHeld: { count: 1 },
      itemsNotAddedLimit: { count: 1 },
      itemRemoved: { item: "Apple" },
      unresolvedValue: { value: "404" },
      resultsCount: { count: 3 },
      resultsLoaded: { count: 3 },
      createItem: { label: "Pear" },
      compactCount: { count: 2 },
      moreChips: { count: 2 },
    }[row.key] ?? {};
  assert.deepEqual(
    values,
    expected,
    `${row.key} receives the documented values`
  );
}

function assertPlaceholderDescription(assert, selector, description) {
  const ids =
    find(selector)
      .getAttribute("aria-describedby")
      ?.split(/\s+/)
      .filter(Boolean) ?? [];
  if (description === "none") {
    assert.deepEqual(
      ids,
      [],
      "without another description no placeholder id is added"
    );
    assert.false(
      findAll(".sr-only").some(
        (element) => element.textContent.trim() === "Empty prompt"
      ),
      "there is no redundant hidden placeholder"
    );
    return ids;
  }
  assert.true(
    ids.length >= 2,
    "the input has the placeholder and the existing description"
  );
  const first = document.getElementById(ids[0]);
  assert
    .dom(first)
    .hasClass("sr-only", "the first description is visually hidden")
    .hasText(
      description === "chips" ? "Held prompt" : "Empty prompt",
      "the first description repeats the actual input placeholder"
    );
  assert.strictEqual(
    findAll(".sr-only").filter(
      (element) => element.textContent.trim() === first?.textContent.trim()
    ).length,
    1,
    "the placeholder description is rendered once"
  );
  if (description === "consumer") {
    assert.strictEqual(
      ids[1],
      "texts-description",
      "the consumer id follows the placeholder id"
    );
  } else {
    assert
      .dom(document.getElementById(ids[1]))
      .hasText(
        i18n("d_select.chips_hint"),
        "the interactive chip hint follows the placeholder"
      );
  }
  return ids;
}

function assertDescriptionRemoved(assert, selector, ids) {
  assert
    .dom(selector)
    .doesNotHaveAttribute(
      "placeholder",
      "empty removes the placeholder attribute"
    );
  assert.strictEqual(
    document.getElementById(ids[0]),
    null,
    "empty removes its hidden description"
  );
  assert.deepEqual(
    find(selector).getAttribute("aria-describedby").split(/\s+/),
    ids.slice(1),
    "empty removes only the placeholder reference"
  );
}

/** Each branch passes only the named legacy argument, so warning counts stay attributable. */
async function mountLegacy(name, label, load) {
  switch (name) {
    case "ariaLabel":
      await render(
        <template><DSelect @ariaLabel={{label}} @items={{ITEMS}} /></template>
      );
      break;
    case "placeholder":
      await render(
        <template><DSelect @items={{ITEMS}} @placeholder={{label}} /></template>
      );
      break;
    case "searchPlaceholder":
      await render(
        <template>
          <DSelect
            @items={{ITEMS}}
            @searchPlaceholder={{label}}
            @variant="button"
          />
        </template>
      );
      break;
    case "noResultsLabel":
      await render(
        <template>
          <DSelect @items={{ITEMS}} @noResultsLabel={{label}} />
        </template>
      );
      break;
    case "noneLabel":
      await render(
        <template><DSelect @items={{ITEMS}} @noneLabel={{label}} /></template>
      );
      break;
    case "loadingLabel":
      await render(
        <template><DSelect @load={{load}} @loadingLabel={{label}} /></template>
      );
      break;
  }
}

module("Integration | ui-kit | select | texts", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.warnings = sinon.spy();
    warningSink.value = this.warnings;
    this.announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
  });

  hooks.afterEach(function () {
    warningSink.value = undefined;
    resetOnerror();
    disableVirtualization();
  });

  module("layering", function () {
    test("kindTexts keys are fixed at construction while declared values remain live", async function (assert) {
      const options = tracked(undefined);
      customize((selects) =>
        selects.forIdentifier("texts-test", (spec) =>
          spec.content((items, context) => {
            options.value = context.options;
            return items;
          })
        )
      );
      const state = await mount({ kindTexts: { recipePrompt: "first" } });
      await click(".d-select__trigger");
      assert.strictEqual(
        renderSelectText(options.value, "recipePrompt"),
        "first",
        "the initial recipe key is declared"
      );
      state.value = {
        ...state.value,
        kindTexts: { recipePrompt: "second", latePrompt: "late" },
        texts: { latePrompt: "caller" },
      };
      await settled();
      assert.strictEqual(
        renderSelectText(options.value, "recipePrompt"),
        "second",
        "a declared key's value remains live"
      );
      assert.false(
        Object.hasOwn(options.value.texts, "latePrompt"),
        "a later recipe key is not admitted into the schema"
      );
      assert.strictEqual(
        this.warnings
          .getCalls()
          .filter(
            (call) =>
              call.args[1].id === "discourse.d-select.texts-unknown-key" &&
              call.args[0].includes("latePrompt")
          ).length,
        1,
        "the undeclared call-site entry warns"
      );
    });

    test("kindTextWrappers keys are fixed at construction", async function (assert) {
      const options = tracked(undefined);
      customize((selects) =>
        selects.forIdentifier("texts-test", (spec) =>
          spec.content((items, context) => {
            options.value = context.options;
            return items;
          })
        )
      );
      const state = await mount({
        kindTexts: { recipeText: "recipe", sibling: "sibling" },
        wrappers: { recipeText: (final) => `first(${final})` },
      });
      await click(".d-select__trigger");
      assert.strictEqual(
        renderSelectText(options.value, "recipeText"),
        "first(recipe)",
        "the initial wrapper applies"
      );
      state.value = {
        ...state.value,
        wrappers: {
          recipeText: (final) => `second(${final})`,
          sibling: () => "late wrapper",
        },
      };
      await settled();
      assert.strictEqual(
        renderSelectText(options.value, "recipeText"),
        "second(recipe)",
        "a declared wrapper's value remains live"
      );
      assert.strictEqual(
        renderSelectText(options.value, "sibling"),
        "sibling",
        "adding a new wrapper key later has no effect"
      );
    });

    test("DSelectList forwards kind texts and wrappers across all option layers", async function (assert) {
      customize((selects) => {
        selects.forAll((spec) =>
          spec.options(() => ({ texts: { searchPlaceholder: "all" } }))
        );
        selects.forKind("texts-kind", (spec) =>
          spec.options(() => ({ texts: { searchPlaceholder: "kind" } }))
        );
        selects.forIdentifier("texts-test", (spec) =>
          spec.options(() => ({ texts: { searchPlaceholder: "identifier" } }))
        );
      });
      await mount({
        list: true,
        value: [1],
        kindTexts: { searchPlaceholder: "recipe" },
        texts: { searchPlaceholder: "caller", chipsHint: "Caller chip hint" },
        wrappers: { searchPlaceholder: (final) => `wrapped ${final}` },
      });
      assert
        .dom(".d-select__filter")
        .hasAttribute(
          "placeholder",
          "wrapped identifier",
          "the list wraps the final customization layer"
        );
      assert
        .dom(".d-select__chips > .sr-only[id^='d-select-chip-hint-']")
        .hasText(
          "Caller chip hint",
          "a call-site sibling survives the higher layers"
        );
    });

    test("each of the six layers wins over all lower layers", async function (assert) {
      const tier = tracked(0);
      customize((selects) => {
        selects.forIdentifier("texts-test", (spec) =>
          spec.options(() =>
            tier.value >= 5 ? { texts: { placeholder: "identifier" } } : {}
          )
        );
        selects.forKind("texts-kind", (spec) =>
          spec.options(() =>
            tier.value >= 4
              ? { texts: { placeholder: "kind customization" } }
              : {}
          )
        );
        selects.forAll((spec) =>
          spec.options(() =>
            tier.value >= 3
              ? { texts: { placeholder: "all customization" } }
              : {}
          )
        );
      });
      const state = await mount({ kindTexts: { placeholder: null } });
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          i18n("d_select.placeholder"),
          "the engine default is the lowest layer"
        );
      state.value = { ...state.value, kindTexts: { placeholder: "recipe" } };
      await settled();
      assert
        .dom(".d-select__input")
        .hasAttribute("placeholder", "recipe", "the recipe beats the engine");
      state.value = { ...state.value, texts: { placeholder: "call site" } };
      await settled();
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          "call site",
          "the call site beats the recipe"
        );
      for (const [level, expected] of [
        [3, "all customization"],
        [4, "kind customization"],
        [5, "identifier"],
      ]) {
        tier.value = level;
        await settled();
        assert
          .dom(".d-select__input")
          .hasAttribute(
            "placeholder",
            expected,
            `${expected} beats lower tiers even when registered first`
          );
      }
    });

    test("per-entry merging preserves siblings from every layer", async function (assert) {
      const snapshot = tracked(undefined);
      customize((selects) => {
        selects.forAll((spec) =>
          spec.options(() => ({
            texts: { placeholder: "all", noResults: "all sibling" },
          }))
        );
        selects.forKind("texts-kind", (spec) =>
          spec.options(() => ({
            texts: { placeholder: "kind", searchPlaceholder: "kind sibling" },
          }))
        );
        selects.forIdentifier("texts-test", (spec) => {
          spec.options(() => ({
            texts: {
              placeholder: "identifier",
              minChars: "identifier sibling",
            },
          }));
          spec.content((items, context) => {
            snapshot.value = context.options;
            return items;
          });
        });
      });
      await mount({
        kindTexts: {
          placeholder: "recipe",
          addMorePlaceholder: "recipe sibling",
        },
        texts: { placeholder: "call", chipsHint: "call sibling" },
      });
      await click(".d-select__trigger");
      for (const [key, expected] of Object.entries({
        placeholder: "identifier",
        addMorePlaceholder: "recipe sibling",
        chipsHint: "call sibling",
        noResults: "all sibling",
        searchPlaceholder: "kind sibling",
        minChars: "identifier sibling",
        clear: i18n("d_select.clear"),
      })) {
        assert.strictEqual(
          renderSelectText(snapshot.value, key),
          expected,
          `${key} survives higher entry overrides`
        );
      }
    });

    for (const tier of ["forAll", "forKind", "forIdentifier"]) {
      test(`registration order within ${tier} is respected`, async function (assert) {
        customize((selects) => {
          const add = (setup) =>
            tier === "forAll"
              ? selects.forAll(setup)
              : selects[tier](
                  tier === "forKind" ? "texts-kind" : "texts-test",
                  setup
                );
          add((spec) =>
            spec.options(() => ({
              texts: {
                placeholder: "earlier",
                searchPlaceholder: "earlier sibling",
              },
            }))
          );
          add((spec) =>
            spec.options(() => ({ texts: { placeholder: "later" } }))
          );
        });
        await mount({ variant: "button" });
        assert
          .dom(".d-select__placeholder")
          .hasText("later", "the later registration wins");
        await click(".d-select__trigger");
        assert
          .dom(".d-select__filter")
          .hasAttribute(
            "placeholder",
            "earlier sibling",
            "an earlier sibling is retained"
          );
      });
    }

    test("nullish entries at every higher tier are no-ops", async function (assert) {
      customize((selects) => {
        selects.forAll((spec) =>
          spec.options(() => ({
            texts: { placeholder: null, searchPlaceholder: undefined },
          }))
        );
        selects.forKind("texts-kind", (spec) =>
          spec.options(() => ({
            texts: { placeholder: undefined, searchPlaceholder: null },
          }))
        );
        selects.forIdentifier("texts-test", (spec) =>
          spec.options(() => ({
            texts: {
              placeholder: () => null,
              searchPlaceholder: () => undefined,
            },
          }))
        );
      });
      await mount({
        variant: "button",
        kindTexts: {
          placeholder: "recipe prompt",
          searchPlaceholder: "recipe search",
        },
        texts: { placeholder: null, searchPlaceholder: undefined },
      });
      assert
        .dom(".d-select__placeholder")
        .hasText(
          "recipe prompt",
          "nullish entries and function results preserve the recipe"
        );
      await click(".d-select__trigger");
      assert
        .dom(".d-select__filter")
        .hasAttribute(
          "placeholder",
          "recipe search",
          "undefined does not erase a sibling"
        );
    });

    test("an empty highest layer omits the place", async function (assert) {
      forIdentifier({ placeholder: "" });
      await mount({
        kindTexts: { placeholder: "recipe" },
        texts: { placeholder: "call" },
        variant: "button",
      });
      assert
        .dom(".d-select__placeholder")
        .doesNotExist(
          "an explicit empty entry is not replaced with a lower prompt or empty span"
        );
    });

    test("own-key lookup walks every layer exactly once", async function (assert) {
      const decorate = (layer) => (_values, context) =>
        `${layer}(${context.text("placeholder")})`;
      customize((selects) => {
        selects.forAll((spec) =>
          spec.options(() => ({ texts: { placeholder: decorate("all") } }))
        );
        selects.forKind("texts-kind", (spec) =>
          spec.options(() => ({ texts: { placeholder: decorate("kind") } }))
        );
        selects.forIdentifier("texts-test", (spec) =>
          spec.options(() => ({
            texts: { placeholder: decorate("identifier") },
          }))
        );
      });
      await mount({
        kindTexts: { placeholder: decorate("recipe") },
        texts: { placeholder: decorate("call") },
      });
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          `identifier(kind(all(call(recipe(${i18n("d_select.placeholder")})))))`,
          "self lookup descends from the evaluating layer, including to the engine"
        );
    });

    test("a wrapper runs once after the final customization, including empty final", async function (assert) {
      const final = tracked("identifier prompt");
      const options = tracked(undefined);
      const wrap = sinon.spy(
        (text, _values, context) =>
          `wrap(${text}/${context.text("recipeText")})`
      );
      customize((selects) =>
        selects.forIdentifier("texts-test", (spec) => {
          spec.options(() => ({ texts: { recipeText: final.value } }));
          spec.content((items, context) => {
            options.value = context.options;
            return items;
          });
        })
      );
      await mount({
        kindTexts: { recipeText: "recipe" },
        texts: { recipeText: "call" },
        wrappers: { recipeText: wrap },
      });
      await click(".d-select__trigger");
      wrap.resetHistory();
      assert.strictEqual(
        renderSelectText(options.value, "recipeText"),
        "wrap(identifier prompt/identifier prompt)",
        "wrapper runs above the identifier tier"
      );
      assert.strictEqual(
        wrap.callCount,
        1,
        "self lookup does not wrap recursively"
      );
      final.value = "";
      await settled();
      wrap.resetHistory();
      assert.strictEqual(
        renderSelectText(options.value, "recipeText"),
        "wrap(/)",
        "empty final reaches the wrapper"
      );
      assert.strictEqual(wrap.callCount, 1, "empty final wraps once too");
    });

    test("customization snapshots render their own preceding layers without re-entry", async function (assert) {
      const preceding = tracked(undefined);
      customize((selects) => {
        selects.forAll((spec) =>
          spec.options((current) => {
            preceding.value = current;
            return {
              texts: {
                placeholder: `all(${renderSelectText(current, "placeholder")})`,
              },
            };
          })
        );
        selects.forKind("texts-kind", (spec) =>
          spec.options((current) => ({
            texts: {
              placeholder: `kind(${renderSelectText(current, "placeholder")})`,
            },
          }))
        );
      });
      const state = await mount({ texts: { placeholder: "first" } });
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          "kind(all(first))",
          "each callback renders the preceding snapshot"
        );
      const old = preceding.value;
      state.value = { ...state.value, texts: { placeholder: "second" } };
      await settled();
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          "kind(all(second))",
          "the new snapshot uses the changed call site"
        );
      assert.strictEqual(
        renderSelectText(old, "placeholder"),
        "first",
        "a retained snapshot never reads the engine's latest options"
      );
    });

    test("merged texts are copied and frozen without freezing the caller hash", async function (assert) {
      const texts = { placeholder: "caller" };
      const options = tracked(undefined);
      customize((selects) =>
        selects.forIdentifier("texts-test", (spec) =>
          spec.content((items, context) => {
            options.value = context.options;
            return items;
          })
        )
      );
      await mount({ texts });
      await click(".d-select__trigger");
      assert.true(
        Object.isFrozen(options.value),
        "the resolved snapshot is frozen"
      );
      assert.true(
        Object.isFrozen(options.value.texts),
        "its merged texts are frozen"
      );
      assert.false(
        Object.isFrozen(texts),
        "the caller keeps ownership of its hash"
      );
      assert.notStrictEqual(
        options.value.texts,
        texts,
        "the snapshot owns a copy"
      );
      assert.strictEqual(
        options.value.texts.placeholder,
        "caller",
        "callbacks can inspect merged entries"
      );
    });
  });

  module("completeness per use", function () {
    test("every default key has at least one use row", function (assert) {
      const covered = new Set(USES.map((row) => row.key));
      assert.deepEqual(
        [...covered].sort(),
        Object.keys(DEFAULT_SELECT_TEXTS).sort(),
        "the use matrix and exported defaults cover exactly the same keys"
      );
    });

    for (const row of USES) {
      for (const source of [
        "@texts",
        "forIdentifier",
        REQUIRED.has(row.key) ? "required empty" : "empty",
      ]) {
        test(`${row.key}: ${row.place} via ${source}`, async function (assert) {
          if (row.touch) {
            sinon
              .stub(this.owner.lookup("service:capabilities"), "touch")
              .get(() => true);
          }
          const empty = source === "empty" || source === "required empty";
          const expected = empty ? "" : `Custom ${row.key} / ${row.place}`;
          const text = sinon.spy(() => expected);
          const texts = { [row.key]: empty ? "" : text };
          if (source === "forIdentifier") {
            forIdentifier(texts);
          }
          const configuration = source === "forIdentifier" ? {} : { texts };
          const action = () =>
            drive(row, configuration, () => {
              assertUse(assert, row, expected, this.announce);
              if (!empty) {
                assertValues(assert, row, text);
              }
            });
          if (source === "required empty") {
            await expectAssertion(
              assert,
              () => drive(row, configuration, () => {}),
              new RegExp(row.key)
            );
          } else {
            await action();
          }
        });
      }
    }
  });

  module("placeholders", function () {
    test("suppressing the only chip hint also removes the placeholder description", async function (assert) {
      await mount({
        multiple: true,
        value: [1],
        texts: { addMorePlaceholder: "Held prompt", chipsHint: "" },
      });
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          "Held prompt",
          "the native placeholder remains"
        )
        .doesNotHaveAttribute(
          "aria-describedby",
          "there is no other description to justify a duplicate"
        );
      assert.false(
        findAll(".sr-only").some(
          (element) => element.textContent.trim() === "Held prompt"
        ),
        "no hidden placeholder is rendered without another description"
      );
    });

    for (const mobile of [false, true]) {
      test(`a single ${mobile ? "mobile modal" : "desktop"} input describes its placeholder first`, async function (assert) {
        await mount({
          mobile,
          describedBy: "texts-description",
          texts: {
            placeholder: "Empty prompt",
            searchPlaceholder: "Empty prompt",
          },
        });
        if (mobile) {
          await click(".d-select__trigger");
        }
        assertPlaceholderDescription(
          assert,
          mobile ? ".d-select__filter" : ".d-select__input",
          "consumer"
        );
      });
    }

    test("empty noResults keeps bookkeeping and cancels a queued count", async function (assert) {
      await mount({
        variant: "button",
        texts: { resultsCount: "Queued result count", noResults: "" },
      });
      await click(".d-select__trigger");
      this.announce.resetHistory();
      typeNow("a", ".d-select__filter");
      await rerender();
      typeNow("Pear", ".d-select__filter");
      await settled();
      assert
        .dom(".d-select__empty")
        .exists("the bookkeeping node survives")
        .hasText("", "it has no message")
        .doesNotHaveAttribute("role", "it has no live role");
      assert.false(
        this.announce.calledWith("Queued result count"),
        "the superseded count is cancelled"
      );
      assert.false(
        this.announce.calledWith(""),
        "empty does not clear the a11y queue"
      );
      assert.false(
        this.announce.calledWith(i18n("d_select.no_results")),
        "the default empty message is not restored"
      );
    });

    test("held desktop inputs default to add_placeholder, including compact inputs", async function (assert) {
      const state = await mount({ multiple: true, value: [1] });
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          i18n("d_select.add_placeholder"),
          "held values get the default add prompt"
        );
      state.value = { ...state.value, maxVisibleChips: 0 };
      await settled();
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          i18n("d_select.add_placeholder"),
          "the compact input keeps the add prompt after its count"
        );
    });

    for (const [name, configuration] of [
      ["nothing held", { value: [] }],
      ["at maximum", { value: [1], maximum: 1 }],
      ["disabled", { value: [1], disabled: true }],
      ["read-only", { value: [1], readonly: true }],
    ]) {
      test(`addMorePlaceholder is gated with ${name}`, async function (assert) {
        await mount({
          multiple: true,
          texts: {
            placeholder: "Empty prompt",
            addMorePlaceholder: "Held prompt",
          },
          ...configuration,
        });
        if (name === "nothing held") {
          assert
            .dom(".d-select__input")
            .hasAttribute(
              "placeholder",
              "Empty prompt",
              "empty inputs use placeholder rather than addMorePlaceholder"
            );
        } else {
          assert
            .dom(".d-select__input")
            .doesNotHaveAttribute(
              "placeholder",
              "the held prompt is omitted when another item cannot be added"
            );
        }
      });
    }

    test("a single-select with a value never draws addMorePlaceholder", async function (assert) {
      await mount({ value: 1, texts: { addMorePlaceholder: "Held prompt" } });
      assert
        .dom(".d-select__input")
        .doesNotHaveAttribute(
          "placeholder",
          "single selection does not use a held multi prompt"
        );
    });

    test("addMorePlaceholder values include selected and bounds, omitting an uncapped maximum", async function (assert) {
      const prompt = sinon.spy((values) => `Held ${values.selected}`);
      const state = await mount({
        multiple: true,
        value: [1],
        minimum: 2,
        maximum: 4,
        texts: { addMorePlaceholder: prompt },
      });
      assert.deepEqual(
        prompt.lastCall.args[0],
        { selected: 1, minimum: 2, maximum: 4 },
        "the held prompt gets numeric selection progress and bounds"
      );
      state.value = { ...state.value, maximum: false, value: [1, 2] };
      await settled();
      assert.strictEqual(
        prompt.lastCall.args[0].selected,
        2,
        "selection progress updates"
      );
      assert.false(
        Object.hasOwn(prompt.lastCall.args[0], "maximum"),
        "an uncapped maximum is absent rather than null"
      );
    });

    for (const variant of ["button", "static", "mobile"]) {
      test(`addMorePlaceholder never draws beside chips on a ${variant} trigger`, async function (assert) {
        await mount({
          multiple: true,
          value: [1],
          variant: variant === "mobile" ? undefined : variant,
          mobile: variant === "mobile",
          texts: { addMorePlaceholder: "Held prompt" },
        });
        assert
          .dom(".d-select__trigger .d-select__chip")
          .exists("the trigger shows its held chip");
        assert
          .dom(".d-select__trigger .d-select__placeholder")
          .doesNotExist("there is no prompt span beside it");
        assert
          .dom(".d-select__trigger input[placeholder]")
          .doesNotExist("the trigger has no placeholder input");
      });
    }

    test("the mobile typeahead multi modal follows the empty, held and capped chain", async function (assert) {
      const state = await mount({
        multiple: true,
        mobile: true,
        maximum: 2,
        texts: {
          placeholder: "Empty prompt",
          addMorePlaceholder: "Held prompt",
          searchPlaceholder: "Search fallback",
        },
      });
      await click(".d-select__trigger");
      assert
        .dom(".d-select__filter")
        .hasAttribute(
          "placeholder",
          "Empty prompt",
          "the empty modal uses the same prompt as desktop"
        );
      state.value = { ...state.value, value: [1] };
      await settled();
      assert
        .dom(".d-select__filter")
        .hasAttribute(
          "placeholder",
          "Held prompt",
          "held values switch to the add prompt"
        );
      state.value = { ...state.value, value: [1, 2] };
      await settled();
      assert
        .dom(".d-select__filter")
        .hasAttribute(
          "placeholder",
          "Search fallback",
          "at the cap the modal keeps its search prompt"
        );
      assert
        .dom(".d-select__trigger .d-select__placeholder")
        .doesNotExist("the closed-trigger presentation remains chips");
      state.value = {
        ...state.value,
        value: [1],
        texts: { ...state.value.texts, addMorePlaceholder: "" },
      };
      await settled();
      assert
        .dom(".d-select__filter")
        .doesNotHaveAttribute(
          "placeholder",
          "an intentionally empty held prompt does not fall back to search"
        );
    });

    for (const [name, configuration] of [
      [
        "mobile button multi",
        { mobile: true, multiple: true, variant: "button", value: [1] },
      ],
      ["mobile single", { mobile: true, value: 1 }],
      ["persistent list", { list: true, value: [1] }],
    ]) {
      test(`${name} keeps searchPlaceholder`, async function (assert) {
        await mount({
          ...configuration,
          texts: {
            placeholder: "Empty prompt",
            addMorePlaceholder: "Held prompt",
            searchPlaceholder: "Search prompt",
          },
        });
        if (!configuration.list) {
          await click(".d-select__trigger");
        }
        assert
          .dom(".d-select__filter")
          .hasAttribute(
            "placeholder",
            "Search prompt",
            "this search surface does not use the typeahead multi chain"
          );
      });
    }

    for (const mobile of [false, true]) {
      test(`a pending ${mobile ? "mobile modal" : "desktop"} input suppresses the held prompt`, async function (assert) {
        const pending = gate();
        const action = {
          id: "pending-action",
          name: "Pending action",
          onSelect: (control) => control.update(() => pending.promise),
        };
        await mount({
          multiple: true,
          mobile,
          value: [1],
          items: [...ITEMS, action],
          texts: {
            addMorePlaceholder: "Held prompt",
            searchPlaceholder: "Search fallback",
          },
        });
        await click(".d-select__trigger");
        const choosing = click(optionWithText("Pending action"));
        try {
          await waitFor(".d-select__pending-icon");
          const selector = mobile ? ".d-select__filter" : ".d-select__input";
          if (mobile) {
            assert
              .dom(selector)
              .hasAttribute(
                "placeholder",
                "Search fallback",
                "pending mobile input falls back to the search prompt"
              );
          } else {
            assert
              .dom(selector)
              .doesNotHaveAttribute(
                "placeholder",
                "pending desktop input omits the held prompt"
              );
          }
        } finally {
          pending.resolve();
          await choosing;
        }
      });
    }

    for (const mobile of [false, true]) {
      for (const description of ["none", "consumer", "chips"]) {
        test(`${mobile ? "mobile" : "desktop"} placeholder description with ${description}`, async function (assert) {
          const configuration = {
            multiple: true,
            mobile,
            texts: {
              placeholder: "Empty prompt",
              addMorePlaceholder: "Held prompt",
            },
          };
          if (description === "consumer") {
            configuration.describedBy = "texts-description";
          } else if (description === "chips") {
            configuration.value = [1];
          }
          const state = await mount(configuration);
          if (mobile) {
            await click(".d-select__trigger");
          }
          const selector = mobile ? ".d-select__filter" : ".d-select__input";
          const ids = assertPlaceholderDescription(
            assert,
            selector,
            description
          );
          if (description !== "none") {
            state.value = {
              ...state.value,
              texts: {
                ...state.value.texts,
                placeholder: "",
                addMorePlaceholder: "",
              },
            };
            await settled();
            assertDescriptionRemoved(assert, selector, ids);
          }
        });
      }
    }

    test("minimum receives count and selected for both the line and announcement", async function (assert) {
      const minimum = sinon.spy(
        ({ count, selected }) => `Progress ${selected}/${count}`
      );
      const state = await mount({
        multiple: true,
        minimum: 3,
        value: [1],
        texts: { minimum },
      });
      await click(".d-select__trigger");
      assert
        .dom(".d-select__limit")
        .hasText("Progress 1/3", "the line has selection progress");
      assert.true(
        this.announce.calledWith("Progress 1/3", "polite"),
        "the announcement uses the same progress"
      );
      assert.deepEqual(
        minimum.lastCall.args[0],
        { count: 3, selected: 1 },
        "count means the minimum and selected means held values"
      );
      state.value = { ...state.value, value: [1, 2] };
      await settled();
      assert
        .dom(".d-select__limit")
        .hasText("Progress 2/3", "progress follows external value changes");
      assert.true(
        this.announce.calledWith("Progress 2/3", "polite"),
        "updated progress is announced"
      );
    });
  });

  module("feature switches", function () {
    test("noneRow toggles the none row and its default label", async function (assert) {
      const state = await mount({ value: 1 });
      await click(".d-select__trigger");
      assert
        .dom("[role='option'][data-value='']")
        .doesNotExist("the row is off by default");
      state.value = { ...state.value, noneRow: true };
      await settled();
      assert
        .dom("[role='option'][data-value='']")
        .hasText("None", "the switch enables the contracted default");
      await click("[role='option'][data-value='']");
      assert.strictEqual(state.value.value, null, "the none row selects null");
      state.value = { ...state.value, noneRow: false };
      await settled();
      await click(".d-select__trigger");
      assert
        .dom("[role='option'][data-value='']")
        .doesNotExist("turning the switch off removes the row");
    });

    test("a forAll noneLabel alone never adds a none row", async function (assert) {
      customize((selects) =>
        selects.forAll((spec) =>
          spec.options(() => ({ texts: { noneLabel: "Global none" } }))
        )
      );
      await mount();
      await click(".d-select__trigger");
      assert
        .dom("[role='option'][data-value='']")
        .doesNotExist("rewording does not enable the feature");
      assert
        .dom("[role='option']")
        .exists({ count: ITEMS.length }, "only real items are drawn");
    });

    test("noneRow is ignored for multiple selection", async function (assert) {
      await mount({
        multiple: true,
        noneRow: true,
        texts: { noneLabel: "No fruit" },
      });
      await click(".d-select__trigger");
      assert
        .dom("[role='option'][data-value='']")
        .doesNotExist("the engine none row remains single-select only");
    });

    test("a customization can enable noneRow and customize its text", async function (assert) {
      customize((selects) =>
        selects.forIdentifier("texts-test", (spec) =>
          spec.options(() => ({
            noneRow: true,
            texts: { noneLabel: "Customized none" },
          }))
        )
      );
      await mount();
      await click(".d-select__trigger");
      assert
        .dom("[role='option'][data-value='']")
        .hasText(
          "Customized none",
          "the switch and text resolve through options"
        );
    });

    for (const source of ["argument", "customization", "text alone"]) {
      test(`loadingStatus via ${source} controls the status line`, async function (assert) {
        const pending = gate();
        if (source === "customization") {
          customize((selects) =>
            selects.forIdentifier("texts-test", (spec) =>
              spec.options(() => ({
                loadingStatus: true,
                texts: { loadingLabel: "Customized loading" },
              }))
            )
          );
        }
        await mount({
          load: () => pending.promise,
          loadingStatus: source === "argument",
          texts:
            source === "text alone"
              ? { loadingLabel: "Text without switch" }
              : undefined,
        });
        const opening = click(".d-select__trigger");
        try {
          await waitFor(".d-select__skeleton");
          if (source === "text alone") {
            assert
              .dom(".d-select__loading-status")
              .doesNotExist("a text alone does not enable the line");
          } else {
            assert
              .dom(".d-select__loading-status")
              .hasText(
                source === "argument" ? "Loading…" : "Customized loading",
                "the enabled status uses its resolved text"
              );
          }
        } finally {
          pending.resolve(ITEMS);
          await opening;
        }
        assert
          .dom(".d-select__loading-status")
          .doesNotExist("the status leaves when loading completes");
      });
    }

    test("empty switch labels are allowed while their switches are off", async function (assert) {
      await mount({ texts: { noneLabel: "", loadingLabel: "" } });
      await click(".d-select__trigger");
      assert
        .dom("[role='option'][data-value='']")
        .doesNotExist("empty noneLabel with no noneRow is valid");
      assert
        .dom(".d-select__loading-status")
        .doesNotExist("empty loadingLabel with no loadingStatus is valid");
    });
  });

  module("legacy compatibility", function () {
    for (const name of [
      "ariaLabel",
      "placeholder",
      "searchPlaceholder",
      "noResultsLabel",
      "noneLabel",
      "loadingLabel",
    ]) {
      test(`legacy argument @${name} still works and warns`, async function (assert) {
        const label = `Legacy ${name}`;
        const pending = gate();
        await mountLegacy(name, label, () => pending.promise);
        if (name === "loadingLabel") {
          const opening = click(".d-select__trigger");
          try {
            await waitFor(".d-select__skeleton");
            assert
              .dom(".d-select__loading-status")
              .hasText(label, "the old loading label still enables the line");
          } finally {
            pending.resolve(ITEMS);
            await opening;
          }
        } else if (name === "ariaLabel") {
          assert
            .dom(".d-select__input")
            .hasAttribute(
              "aria-label",
              label,
              "the legacy name still labels the input"
            );
        } else if (name === "placeholder") {
          assert
            .dom(".d-select__input")
            .hasAttribute(
              "placeholder",
              label,
              "the old placeholder still renders"
            );
        } else {
          await click(".d-select__trigger");
          if (name === "searchPlaceholder") {
            assert
              .dom(".d-select__filter")
              .hasAttribute(
                "placeholder",
                label,
                "the old search prompt still renders"
              );
          } else if (name === "noneLabel") {
            assert
              .dom("[role='option'][data-value='']")
              .hasText(label, "the old none label still enables the row");
          } else {
            await fillIn(".d-select__input", "Pear");
            assert
              .dom(".d-select__empty")
              .hasText(label, "the old empty-state label still renders");
          }
        }
        const announcementPreserved =
          name !== "noResultsLabel" ||
          this.announce.calledWith(label, "polite");
        assert.true(
          announcementPreserved,
          "the old empty-state label is still announced when used"
        );
        const notices = this.warnings
          .getCalls()
          .filter(
            (call) => call.args[1].id === "discourse.d-select.texts-legacy"
          );
        assert.strictEqual(
          notices.length,
          1,
          "this argument warns once per select"
        );
        assert.true(
          notices[0]?.args[0].includes(name),
          "the warning identifies the legacy argument"
        );
      });
    }

    for (const name of [
      "ariaLabel",
      "placeholder",
      "searchPlaceholder",
      "noneLabel",
      "loadingLabel",
    ]) {
      test(`legacy option ${name} still works and warns`, async function (assert) {
        const label = `Legacy option ${name}`;
        const pending = gate();
        const snapshot = tracked(undefined);
        customize((selects) =>
          selects.forIdentifier("texts-test", (spec) => {
            spec.options(() => ({ [name]: label }));
            spec.options((current) => {
              snapshot.value = current;
              return {};
            });
          })
        );
        await mount({
          variant: name === "searchPlaceholder" ? "button" : undefined,
          load: name === "loadingLabel" ? () => pending.promise : undefined,
        });
        if (name === "loadingLabel") {
          const opening = click(".d-select__trigger");
          try {
            await waitFor(".d-select__skeleton");
            assert
              .dom(".d-select__loading-status")
              .hasText(label, "the old option still enables loading status");
          } finally {
            pending.resolve(ITEMS);
            await opening;
          }
        } else if (name === "ariaLabel" || name === "placeholder") {
          assert
            .dom(".d-select__input")
            .hasAttribute(
              name === "ariaLabel" ? "aria-label" : "placeholder",
              label,
              "the old option still supplies text"
            );
        } else {
          await click(".d-select__trigger");
          if (name === "noneLabel") {
            assert
              .dom("[role='option'][data-value='']")
              .hasText(label, "the old option still enables the none row");
          } else {
            assert
              .dom(".d-select__filter")
              .hasAttribute(
                "placeholder",
                label,
                "the old search option still renders"
              );
          }
        }
        assert.strictEqual(
          snapshot.value[name],
          label,
          "the legacy option remains readable on a resolved snapshot"
        );
        const notices = this.warnings
          .getCalls()
          .filter(
            (call) => call.args[1].id === "discourse.d-select.texts-legacy"
          );
        assert.strictEqual(
          notices.length,
          1,
          "this option warns once per select"
        );
        assert.true(
          notices[0]?.args[0].includes(name),
          "the warning identifies the legacy option"
        );
      });
    }

    test("new texts beat legacy option keys at the same layer", async function (assert) {
      customize((selects) =>
        selects.forIdentifier("texts-test", (spec) =>
          spec.options(() => ({
            placeholder: "Legacy option",
            texts: { placeholder: "New option" },
          }))
        )
      );
      await mount();
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          "New option",
          "texts wins within a customization result"
        );
    });

    test("old empty arguments retain their fallback during the shim", async function (assert) {
      await mountLegacy("placeholder", "");
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          i18n("d_select.placeholder"),
          "the legacy empty placeholder keeps today's fallback"
        );
    });
  });

  module("warnings", function () {
    test("an unknown forAll text warns once across two selects", async function (assert) {
      customize((selects) =>
        selects.forAll((spec) =>
          spec.options(() => ({ texts: { unknownTypo: "unknown" } }))
        )
      );
      await render(
        <template>
          <DSelect @identifier="first-texts-select" @items={{ITEMS}} />
          <DSelect @identifier="second-texts-select" @items={{ITEMS}} />
        </template>
      );
      assert.strictEqual(
        this.warnings
          .getCalls()
          .filter(
            (call) =>
              call.args[1].id === "discourse.d-select.texts-unknown-key" &&
              call.args[0].includes("unknownTypo")
          ).length,
        1,
        "the unknown key warns once across both selects"
      );
    });

    for (const source of ["@texts", "customization"]) {
      test(`an unknown key in ${source} warns once per key per select`, async function (assert) {
        const texts = { noResultz: "typo", otherTypo: "another typo" };
        if (source === "customization") {
          forIdentifier(texts);
        }
        const state = await mount({
          texts: source === "@texts" ? texts : undefined,
        });
        await click(".d-select__trigger");
        state.value = { ...state.value, value: 1 };
        await settled();
        const notices = this.warnings
          .getCalls()
          .filter(
            (call) => call.args[1].id === "discourse.d-select.texts-unknown-key"
          );
        assert.strictEqual(
          notices.length,
          2,
          "each unknown entry warns once despite re-resolution"
        );
        for (const key of Object.keys(texts)) {
          assert.strictEqual(
            notices.filter((call) => call.args[0].includes(key)).length,
            1,
            `${key} is identified once`
          );
        }
      });
    }

    for (const [name, entry, id] of [
      [
        "missing translation",
        { key: "d_select.missing_for_texts_test" },
        "discourse.d-select.texts-missing-translation",
      ],
      [
        "translation key supplied as a string",
        "d_select.placeholder",
        "discourse.d-select.texts-translation-key-as-string",
      ],
    ]) {
      test(`a ${name} warns once per select`, async function (assert) {
        const texts = { placeholder: entry };
        const state = tracked(null);
        const onChange = (value) => (state.value = value);
        await render(
          <template>
            <div class="first">
              <DSelect
                @items={{ITEMS}}
                @onChange={{onChange}}
                @texts={{texts}}
                @value={{state.value}}
              />
            </div>
            <div class="second">
              <DSelect @items={{ITEMS}} @texts={{texts}} />
            </div>
          </template>
        );
        await click(".first .d-select__trigger");
        await click(optionWithText("Apple"));
        state.value = null;
        await settled();
        const notices = this.warnings
          .getCalls()
          .filter((call) => call.args[1].id === id);
        assert.strictEqual(
          notices.length,
          2,
          "each select warns once, even after its text is rendered again"
        );
        assert.true(
          notices.every((call) => /placeholder|d_select/.test(call.args[0])),
          "the warning identifies the affected text"
        );
        if (typeof entry === "string") {
          assert
            .dom(".second .d-select__input")
            .hasAttribute(
              "placeholder",
              entry,
              "a warned plain string is still used literally"
            );
        }
      });
    }

    test("declared recipe keys are valid in call-site and customization texts", async function (assert) {
      forIdentifier({ recipePrompt: "custom recipe" });
      await mount({
        kindTexts: { recipePrompt: "recipe" },
        texts: { recipePrompt: "caller" },
      });
      assert.strictEqual(
        this.warnings
          .getCalls()
          .filter(
            (call) => call.args[1].id === "discourse.d-select.texts-unknown-key"
          ).length,
        0,
        "a kind-declared key is recognized at both layers"
      );
    });
  });

  module("development assertions", function () {
    for (const [name, entry] of [
      ["number entry", 42],
      ["boolean entry", false],
      ["array entry", ["text"]],
      ["object without key", {}],
      ["translation object with a non-string key", { key: 42 }],
      ["unexpanded interpolation string", "Choose %{count}"],
      [
        "throwing function",
        () => {
          throw new Error("text failure");
        },
      ],
      ["non-string function result", () => 42],
    ]) {
      test(`rejects a ${name}`, async function (assert) {
        await expectAssertion(
          assert,
          () => mount({ texts: { placeholder: entry } }),
          /placeholder|text/i
        );
      });
    }

    test("rejects a cycle between different texts", async function (assert) {
      await expectAssertion(
        assert,
        () =>
          mount({
            texts: {
              placeholder: (_values, context) =>
                context.text("searchPlaceholder"),
              searchPlaceholder: (_values, context) =>
                context.text("placeholder"),
            },
          }),
        /cycl|placeholder/i
      );
    });

    test("rejects kindTexts without kind", async function (assert) {
      await expectAssertion(
        assert,
        () =>
          mount({
            kind: undefined,
            kindTexts: { placeholder: "Recipe prompt" },
          }),
        /kind/i
      );
    });

    test("rejects kindTextWrappers without kind", async function (assert) {
      await expectAssertion(
        assert,
        () =>
          mount({
            kind: undefined,
            wrappers: { placeholder: (final) => final },
          }),
        /kind/i
      );
    });

    test("rejects a recipe key colliding with a core key ignoring case", async function (assert) {
      await expectAssertion(
        assert,
        () => mount({ kindTexts: { NoResults: "Misspelled core key" } }),
        /NoResults|collid|core/i
      );
    });

    test("rejects a translation missing its required interpolation values", async function (assert) {
      await expectAssertion(
        assert,
        () => mount({ texts: { placeholder: { key: "d_select.item_added" } } }),
        /item|placeholder|interpol/i
      );
    });

    for (const key of REQUIRED) {
      test(`rejects whitespace-only required ${key}`, async function (assert) {
        const row = USES.find((use) => use.key === key);
        if (row.touch) {
          sinon
            .stub(this.owner.lookup("service:capabilities"), "touch")
            .get(() => true);
        }
        await expectAssertion(
          assert,
          () => drive(row, { texts: { [key]: " \t\n " } }, () => {}),
          new RegExp(key)
        );
      });

      test(`rejects a wrapper on required ${key}`, async function (assert) {
        await expectAssertion(
          assert,
          () =>
            mount({
              noneRow: key === "noneLabel",
              loadingStatus: key === "loadingLabel",
              wrappers: { [key]: (final) => final },
            }),
          new RegExp(key)
        );
      });
    }

    test("empty ariaLabel is allowed with ariaLabelledBy and omitted on every surface", async function (assert) {
      await mount({
        mobile: true,
        labelledBy: "texts-caption",
        texts: { ariaLabel: "" },
      });
      assert
        .dom(".d-select__trigger")
        .doesNotHaveAttribute(
          "aria-label",
          "the visible caption replaces the trigger name"
        );
      await click(".d-select__trigger");
      for (const selector of [
        "[role='dialog']",
        ".d-select__filter",
        "[role='listbox']",
      ]) {
        assert
          .dom(selector)
          .exists("the named surface is rendered")
          .doesNotHaveAttribute("aria-label", "the empty label is omitted")
          .hasAttribute(
            "aria-labelledby",
            "texts-caption",
            "the caption names this surface"
          );
      }
    });
  });
});
