import { tracked } from "@glimmer/tracking";
import { click, render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  SelectTextNotices,
  SelectTextResolver,
} from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect from "discourse/ui-kit/select/d-select";
import {
  DEFAULT_SELECT_TEXTS,
  renderSelectText,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const LOCALES = {
  placeholder: "placeholder",
  addMorePlaceholder: "add_placeholder",
  searchPlaceholder: "search_placeholder",
  noResults: "no_results",
  ariaLabel: "label",
  labelWithValue: "label_with_value",
  labelWithCount: "label_with_count",
  footerLabel: "footer_label",
  clear: "clear",
  clearAll: "clear_all",
  selectionCleared: "selection_cleared",
  minChars: "min_chars",
  maximum: "max_reached",
  minimum: "min_not_reached",
  removeHint: "remove_hint",
  chipsLabel: "selected_items",
  stripLabel: "selected_items_list",
  removeItem: "remove_item",
  chipsHint: "chips_hint",
  selectedItemsHint: "selected_items_hint",
  selectedCount: "selected_count",
  updatingSelection: "updating_selection",
  itemSelected: "item_selected",
  itemAdded: "item_added",
  itemsAdded: "items_added",
  itemsNotAddedHeld: "items_not_added_held",
  itemsNotAddedLimit: "items_not_added_limit",
  bulkAddSummary: "bulk_add_summary",
  allAlreadySelected: "all_already_selected",
  itemRemoved: "item_removed",
  loadError: "load_error",
  retry: "retry",
  unresolvedValue: "unresolved_value",
  resultsCount: "results_count",
  resultsLoaded: "results_loaded",
  maxLoaded: "filter_to_narrow",
  stillLoading: "still_loading",
  loadingMore: "loading_more",
  loadingComplete: "loading_complete",
  createItem: "create_item",
};

const VALUES = {
  item: "Apple",
  label: "Fruit",
  value: "Banana",
  count: 2,
  selected: 1,
  added: "accepted",
  not_added: "held",
};

/** Captures the same final snapshot a consumer's content customization receives. */
async function snapshot(context, configuration = {}) {
  const captured = tracked(undefined);
  withPluginApi((api) =>
    api.registerValueTransformer("select-customizations", ({ value }) =>
      value.forIdentifier("texts-unit", (spec) =>
        spec.content((items, resolved) => {
          captured.value = resolved.options;
          return items;
        })
      )
    )
  );
  context.Select = DSelect;
  context.configuration = tracked(configuration);
  await render(hbs`
    <this.Select
      @identifier="texts-unit"
      @items={{this.configuration.value.items}}
      @kind="texts-unit-kind"
      @kindTexts={{this.configuration.value.kindTexts}}
      @kindTextWrappers={{this.configuration.value.wrappers}}
      @multiple={{this.configuration.value.multiple}}
      @texts={{this.configuration.value.texts}}
    />
  `);
  await click(".d-select__trigger");
  return captured.value;
}

module("Unit | ui-kit | select | texts", function (hooks) {
  setupRenderingTest(hooks);

  test("DEFAULT_SELECT_TEXTS is frozen and lists exactly the engine keys", function (assert) {
    assert.true(Object.isFrozen(DEFAULT_SELECT_TEXTS), "the map is immutable");
    assert.deepEqual(
      Object.keys(DEFAULT_SELECT_TEXTS).sort(),
      [
        ...Object.keys(LOCALES),
        "compactCount",
        "moreChips",
        "noneLabel",
        "loadingLabel",
      ].sort(),
      "no default is missing or accidentally added"
    );
  });

  test("defaults render the documented locale map and four new strings", async function (assert) {
    const options = await snapshot(this);
    assert.strictEqual(
      typeof options,
      "object",
      "a real select published its resolved options"
    );
    for (const [key, locale] of Object.entries(LOCALES)) {
      assert.strictEqual(
        renderSelectText(options, key, VALUES),
        i18n(`d_select.${locale}`, VALUES),
        `${key} preserves its existing translation`
      );
    }
    for (const [key, expected] of Object.entries({
      compactCount: "2",
      moreChips: "+2",
      noneLabel: "None",
      loadingLabel: "Loading…",
    })) {
      assert.strictEqual(
        renderSelectText(options, key, VALUES),
        expected,
        `${key} has its contracted default`
      );
    }
  });

  test("the multiple default placeholder uses add_placeholder", async function (assert) {
    const options = await snapshot(this, { multiple: true });
    assert.strictEqual(
      renderSelectText(options, "placeholder"),
      i18n("d_select.add_placeholder"),
      "multiple selects use the add prompt"
    );
  });

  test("a retained snapshot preserves its multiple context", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: { recipeText: (_values, context) => String(context.multiple) },
    });
    this.configuration.value = { ...this.configuration.value, multiple: true };
    await settled();
    assert.strictEqual(
      renderSelectText(options, "placeholder"),
      i18n("d_select.placeholder"),
      "old defaults use the snapshot's single-select state"
    );
    assert.strictEqual(
      renderSelectText(options, "recipeText"),
      "false",
      "old functions use the snapshot's multiple context"
    );
  });

  for (const form of ["string", "translation", "function"]) {
    test(`every engine key accepts the ${form} form`, async function (assert) {
      const keys = [
        ...Object.keys(LOCALES),
        "compactCount",
        "moreChips",
        "noneLabel",
        "loadingLabel",
      ];
      const texts = Object.fromEntries(
        keys.map((key) => [
          key,
          form === "translation"
            ? { key: "d_select.retry" }
            : form === "function"
              ? () => `custom ${key}`
              : `custom ${key}`,
        ])
      );
      const options = await snapshot(this, { texts });
      for (const key of keys) {
        assert.strictEqual(
          renderSelectText(options, key, VALUES),
          form === "translation" ? i18n("d_select.retry") : `custom ${key}`,
          `${key} accepts ${form}`
        );
      }
    });
  }

  test("translation objects receive interpolation values and plural counts", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: { recipeText: { key: "d_select.items_added" } },
    });
    for (const count of [1, 3]) {
      assert.strictEqual(
        renderSelectText(options, "recipeText", { count }),
        i18n("d_select.items_added", { count }),
        `numeric count ${count} reaches i18n`
      );
    }
  });

  test("null and undefined defer while an empty string is a value", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: {
        nullText: "under null",
        undefinedText: "under undefined",
        emptyText: "under empty",
      },
      texts: { nullText: null, undefinedText: undefined, emptyText: "" },
    });
    assert.strictEqual(
      renderSelectText(options, "nullText"),
      "under null",
      "null defers"
    );
    assert.strictEqual(
      renderSelectText(options, "undefinedText"),
      "under undefined",
      "undefined defers"
    );
    assert.strictEqual(
      renderSelectText(options, "emptyText"),
      "",
      "empty does not defer"
    );
  });

  test("function values receive values and the select context", async function (assert) {
    const seen = sinon.spy(
      (values, context) =>
        `${context.kind}/${context.identifier}/${context.multiple}/${values.count}`
    );
    const options = await snapshot(this, {
      multiple: true,
      kindTexts: { recipeText: seen },
    });
    assert.strictEqual(
      renderSelectText(options, "recipeText", { count: 7 }),
      "texts-unit-kind/texts-unit/true/7",
      "the public context names the select"
    );
    assert.deepEqual(
      seen.lastCall.args[0],
      { count: 7 },
      "the function gets the supplied values"
    );
    assert.strictEqual(
      typeof seen.lastCall.args[1].text,
      "function",
      "the context exposes text"
    );
    assert.strictEqual(
      renderSelectText(options, "recipeText"),
      "texts-unit-kind/texts-unit/true/undefined",
      "omitted values become an empty object"
    );
  });

  test("a nullish function result defers and an empty result suppresses", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: {
        nullText: "lower null",
        undefinedText: "lower undefined",
        emptyText: "lower empty",
      },
      texts: {
        nullText: () => null,
        undefinedText: () => undefined,
        emptyText: () => "",
      },
    });
    assert.strictEqual(
      renderSelectText(options, "nullText"),
      "lower null",
      "null hands back to the previous layer"
    );
    assert.strictEqual(
      renderSelectText(options, "undefinedText"),
      "lower undefined",
      "undefined hands back too"
    );
    assert.strictEqual(
      renderSelectText(options, "emptyText"),
      "",
      "an empty function result is final"
    );
  });

  test("text(ownKey) decorates the immediately lower layer", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: { recipeText: "base" },
      texts: {
        recipeText: (_values, context) => `call(${context.text("recipeText")})`,
      },
    });
    assert.strictEqual(
      renderSelectText(options, "recipeText"),
      "call(base)",
      "self lookup does not recurse or skip the recipe"
    );
  });

  test("text(otherKey) reads merged unwrapped text and explicit values", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: { recipeText: "base", sibling: "recipe sibling" },
      texts: {
        sibling: (values) => `sibling ${values.count}`,
        recipeText: (_values, context) => context.text("sibling", { count: 9 }),
      },
      wrappers: { sibling: (final) => `wrapped ${final}` },
    });
    assert.strictEqual(
      renderSelectText(options, "recipeText", { count: 2 }),
      "sibling 9",
      "cross lookup sees the call-site entry without its wrapper"
    );
    assert.strictEqual(
      renderSelectText(options, "sibling", { count: 2 }),
      "wrapped sibling 2",
      "a direct render still wraps that key"
    );
  });

  test("text(otherKey) also accepts omitted values", async function (assert) {
    const options = await snapshot(this, {
      kindTexts: {
        recipeText: (_values, context) => context.text("searchPlaceholder"),
      },
      texts: { searchPlaceholder: "Merged search" },
      wrappers: { searchPlaceholder: (final) => `Wrapped ${final}` },
    });
    assert.strictEqual(
      renderSelectText(options, "recipeText"),
      "Merged search",
      "a bare cross-key lookup returns the merged unwrapped text"
    );
  });

  test("a wrapper runs once per render and sees final through text(ownKey)", async function (assert) {
    const wrap = sinon.spy(
      (final, values, context) =>
        `${final}/${context.text("recipeText")}/${values.count}/${context.multiple}`
    );
    const options = await snapshot(this, {
      kindTexts: { recipeText: "recipe" },
      texts: { recipeText: "call" },
      wrappers: { recipeText: wrap },
    });
    wrap.resetHistory();
    assert.strictEqual(
      renderSelectText(options, "recipeText", { count: 4 }),
      "call/call/4/false",
      "wrapper self lookup returns the merged final"
    );
    assert.strictEqual(
      wrap.callCount,
      1,
      "self lookup does not run the wrapper twice"
    );
  });

  test("a wrapper is called with an empty final and can supply text", async function (assert) {
    const wrap = sinon.spy((final) => `guidance(${final})`);
    const options = await snapshot(this, {
      kindTexts: { recipeText: "recipe" },
      texts: { recipeText: "" },
      wrappers: { recipeText: wrap },
    });
    wrap.resetHistory();
    assert.strictEqual(
      renderSelectText(options, "recipeText"),
      "guidance()",
      "empty final still enters the wrapper"
    );
    assert.true(
      wrap.calledOnceWith(""),
      "the wrapper receives exactly one empty final"
    );
  });

  for (const result of [null, undefined]) {
    test(`a wrapper returning ${result} defers to final`, async function (assert) {
      const options = await snapshot(this, {
        kindTexts: { recipeText: "final" },
        wrappers: { recipeText: () => result },
      });
      assert.strictEqual(
        renderSelectText(options, "recipeText"),
        "final",
        "a nullish wrapper result preserves final"
      );
    });
  }

  for (const [name, makeText] of [
    [
      "a throwing function",
      () => () => {
        throw new Error("text failure");
      },
    ],
    ["a non-string function result", () => () => 42],
    [
      "a real cycle between texts",
      () => (_values, context) => context.text("sibling"),
    ],
  ]) {
    test(`renderSelectText asserts for ${name}`, async function (assert) {
      const invalid = tracked(false);
      const text = makeText();
      const options = await snapshot(this, {
        kindTexts: {
          recipeText: (values, context) =>
            invalid.value ? text(values, context) : "valid",
          sibling: (_values, context) => context.text("recipeText"),
        },
      });
      invalid.value = true;
      assert.throws(
        () => renderSelectText(options, "recipeText"),
        /Assertion Failed/i,
        "the renderer raises an Ember development assertion"
      );
    });
  }

  for (const [name, wrap] of [
    [
      "throws",
      () => {
        throw new Error("recipeText wrapper failure");
      },
    ],
    ["returns a non-string", () => 42],
  ]) {
    test(`a wrapper that ${name} asserts`, async function (assert) {
      const options = await snapshot(this, {
        kindTexts: { recipeText: "valid" },
        wrappers: { recipeText: wrap },
      });
      assert.throws(
        () => renderSelectText(options, "recipeText"),
        /Assertion Failed/i,
        "wrapper errors follow the function validation rule"
      );
    });
  }
});

module("Unit | ui-kit | select | texts | fallback", function (hooks) {
  setupRenderingTest(hooks);

  /** A resolver over `texts` layers, lowest first, recording what it reports. */
  function resolver(
    layers,
    { notices = new SelectTextNotices(), wrappers } = {}
  ) {
    const reported = [];
    const instance = new SelectTextResolver({
      layers: layers.map((texts, index) => ({
        source: `layer ${index}`,
        texts,
      })),
      wrappers,
      kind: undefined,
      identifier: undefined,
      multiple: false,
      notices,
      report: (message) => reported.push(message),
    });
    return { instance, reported };
  }

  test("an empty required text falls back one layer", function (assert) {
    const { instance, reported } = resolver([
      { clear: "Erase" },
      { clear: "" },
    ]);

    assert.strictEqual(
      instance.render("clear"),
      "Erase",
      "the layer below the empty text wins"
    );
    assert.strictEqual(reported.length, 1, "the empty text is reported");
  });

  test("an empty required text with nothing below it falls back to the default", function (assert) {
    const { instance, reported } = resolver([{ clear: "" }]);

    assert.strictEqual(instance.render("clear"), i18n("d_select.clear"));
    assert.strictEqual(reported.length, 1, "the empty text is reported");
  });

  test("a wrapper that empties a required text falls back to the text it wrapped", function (assert) {
    const { instance, reported } = resolver([{ clear: "Erase" }], {
      wrappers: { clear: () => "" },
    });

    assert.strictEqual(instance.render("clear"), "Erase");
    assert.strictEqual(reported.length, 1, "the empty result is reported");
  });

  test("a broken text is reported once per select", function (assert) {
    const notices = new SelectTextNotices();
    const broken = {
      noResults: () => {
        throw new Error("broken");
      },
    };
    const { instance, reported } = resolver([broken], { notices });

    instance.render("noResults");
    instance.render("noResults");
    assert.strictEqual(reported.length, 1, "a second read reports nothing");

    const other = resolver([broken], { notices });
    other.instance.render("noResults");
    assert.strictEqual(
      other.reported.length,
      0,
      "a later snapshot of the same select reports nothing either"
    );
  });

  test("each select and each broken key reports on its own", function (assert) {
    const broken = () => {
      throw new Error("broken");
    };
    const first = resolver([{ noResults: broken, retry: broken }]);
    const second = resolver([{ noResults: broken }]);

    first.instance.render("noResults");
    first.instance.render("retry");
    second.instance.render("noResults");

    assert.strictEqual(first.reported.length, 2, "one report per key");
    assert.strictEqual(second.reported.length, 1, "another select reports too");
  });

  test("a text reading its own key gets the layer below with the values it passes", function (assert) {
    const { instance } = resolver([
      { minimum: (values) => `at least ${values.count}` },
      {
        minimum: (values, context) =>
          `${context.text("minimum", { count: values.count - 1 })} / ${context.text("minimum")}`,
      },
    ]);

    assert.strictEqual(
      instance.render("minimum", { count: 3 }),
      "at least 2 / at least 3",
      "passed values reach the layer below; no values keeps the original ones"
    );
  });
});
