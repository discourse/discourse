import { type default as Owner, getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { _INTERNAL_SOURCE_KEY } from "discourse/lib/api";
import { registerDeprecationHandler } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupLegacyBridgeCallbacks } from "discourse/tests/helpers/legacy-bridge-helpers";
import type { SelectCustomizationRegistry } from "discourse/ui-kit/select/-internals/engine/customizations";
import SelectEngine, {
  type SelectDescriptor,
  type SelectEngineOptions,
} from "discourse/ui-kit/select/select-engine";

const CONTENT_ID = "discourse.select-kit.modify-select-kit-content";
const ON_CHANGE_ID = "discourse.select-kit.modify-select-kit-on-change";

/** A deprecation the bridge fired, with the plugin it was attributed to. */
interface FiredDeprecation {
  message?: string;
  id?: string;
  source?: { name?: string };
}

/**
 * One deprecation handler for the whole module, recording every fired deprecation, so tests
 * can assert the bridge's deprecations without leaking a handler per test.
 */
const firedDeprecations: FiredDeprecation[] = [];
let handlerRegistered = false;

/** Plugin api options that attribute the registrations to `name`. */
function pluginOpts(name: string) {
  return { [_INTERNAL_SOURCE_KEY]: Object.freeze({ type: "plugin", name }) };
}

function firedFor(id: string) {
  return firedDeprecations.filter((fired) => fired.id === id);
}

// `buildItems` returns normalized descriptors, so the row id lives on `value`, not on the
// raw model's `id`.
function ids(descriptors: readonly SelectDescriptor[]) {
  return descriptors.map((descriptor) => descriptor.value);
}

/** The parts of the legacy component facade that these tests' callbacks read. */
interface LegacyComponentFacade {
  element: HTMLElement;
  selectKit: {
    close(): void;
    select(...args: unknown[]): void;
    set(key: string, value: unknown): void;
  };
}

module("Unit | ui-kit | modify-select-kit bridge", function (hooks) {
  setupTest(hooks);
  setupLegacyBridgeCallbacks(hooks);

  hooks.beforeEach(function () {
    firedDeprecations.length = 0;
    if (!handlerRegistered) {
      registerDeprecationHandler(
        (message: string, options?: FiredDeprecation) =>
          firedDeprecations.push({
            message,
            id: options?.id,
            source: options?.source,
          })
      );
      handlerRegistered = true;
    }
  });

  // Builds an engine wired for the bridge with a resolvable owner and a live element.
  function engineFor(owner: Owner | undefined, opts: SelectEngineOptions = {}) {
    const element = document.createElement("div");
    return new SelectEngine({
      kind: opts.kind ?? "test-select",
      legacyKinds: opts.legacyKinds,
      identifier: opts.identifier,
      items: opts.items ?? [],
      multiple: opts.multiple ?? false,
      onChange: opts.onChange ?? (() => {}),
      getValue: () => (opts.multiple ? [] : null),
      legacy: {
        owner,
        getElement: () => element,
        isDestroyed: () => false,
      },
    });
  }

  test("applies content callbacks in prepend → append → replace-wins order", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .prependContent(() => ({ id: "pre", name: "Prepended" }));
      api
        .modifySelectKit("test-select")
        .appendContent(() => ({ id: "app", name: "Appended" }));
    });

    const engine = engineFor(getOwner(this));
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(
      ids(items),
      ["pre", "core", "app"],
      "prepend goes first, append last, around the core content"
    );
  });

  test("replaceContent replaces the whole list (replace-wins)", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .prependContent(() => ({ id: "pre", name: "Prepended" }));
      api
        .modifySelectKit("test-select")
        .replaceContent(() => ({ id: "only", name: "Only" }));
    });

    const engine = engineFor(getOwner(this));
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(ids(items), ["only"], "replace wins over the rest");
  });

  test("matches legacy callbacks on the kind, not the identifier", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("category-chooser")
        .appendContent(() => ({ id: "by-kind", name: "By kind" }));
      api
        .modifySelectKit("composer-category")
        .appendContent(() => ({ id: "by-identifier", name: "By identifier" }));
    });

    const engine = engineFor(getOwner(this), {
      kind: "category-chooser",
      identifier: "composer-category",
    });
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(
      ids(items),
      ["core", "by-kind"],
      "only the callback registered on the kind fires"
    );

    const unnamed = engineFor(getOwner(this), {
      kind: undefined,
      identifier: "category-chooser",
    });
    assert.deepEqual(
      ids(unnamed.buildItems([{ id: "core", name: "Core" }])),
      ["core"],
      "an identifier equal to the old name does not reach the bridge"
    );
  });

  test("content callbacks on a legacy name reach the select alongside its kind", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("mini-tag-chooser")
        .appendContent(() => ({ id: "legacy", name: "Legacy" }));
      api
        .modifySelectKit("select-tag")
        .appendContent(() => ({ id: "current", name: "Current" }));
      api
        .modifySelectKit("tag-chooser")
        .appendContent(() => ({ id: "other", name: "Other" }));
    });

    const engine = engineFor(getOwner(this), {
      kind: "select-tag",
      legacyKinds: ["mini-tag-chooser"],
    });
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(
      ids(items).sort(),
      ["core", "current", "legacy"],
      "callbacks on the kind and on the legacy name both run; unrelated names do not"
    );
  });

  test("onChange callbacks on a legacy name run with the legacy signature", function (assert) {
    const calls: unknown[][] = [];
    withPluginApi((api) => {
      api
        .modifySelectKit("tag-dropdown")
        .onChange((component: unknown, value: unknown, item: unknown) =>
          calls.push([value, item])
        );
    });

    const engine = engineFor(getOwner(this), {
      kind: "select-tag",
      legacyKinds: ["tag-dropdown"],
      items: [{ id: 7, name: "Seven" }],
    });
    engine.buildItems([]);
    engine.select({ id: 7, name: "Seven" });

    assert.strictEqual(calls.length, 1, "the onChange callback ran once");
    assert.strictEqual(calls[0][0], 7, "it received the new value");
  });

  test("the deprecation names the legacy name that matched", async function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("mini-tag-chooser")
        .appendContent(() => ({ id: "x", name: "X" }));
    });

    const engine = engineFor(getOwner(this), {
      kind: "select-tag",
      legacyKinds: ["mini-tag-chooser"],
    });
    engine.buildItems([]);
    await settled();

    const [fired] = firedFor(CONTENT_ID);
    assert.true(
      fired?.message?.includes('modifySelectKit("mini-tag-chooser")'),
      "the message names the registration that matched"
    );
  });

  test("several legacy names each match once", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("tags-intersection-chooser")
        .appendContent(() => ({ id: "intersection", name: "Intersection" }));
      api
        .modifySelectKit("mini-tag-chooser")
        .appendContent(() => ({ id: "mini", name: "Mini" }));
    });

    const engine = engineFor(getOwner(this), {
      kind: "select-tag-filter",
      legacyKinds: ["tags-intersection-chooser", "mini-tag-chooser"],
    });
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(
      ids(items).sort(),
      ["core", "intersection", "mini"],
      "each legacy name's callback runs exactly once"
    );
  });

  test("the deprecation names the kind and select-customizations", async function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent(() => ({ id: "x", name: "X" }));
      api.modifySelectKit("test-select").onChange(() => {});
    });

    const engine = engineFor(getOwner(this), {
      items: [{ id: 7, name: "Seven" }],
    });
    engine.buildItems([]);
    engine.select({ id: 7, name: "Seven" });
    await settled();

    for (const id of [CONTENT_ID, ON_CHANGE_ID]) {
      const [fired] = firedFor(id);
      assert.true(
        fired?.message?.includes('modifySelectKit("test-select")'),
        `${id} names the kind`
      );
      assert.true(
        fired?.message?.includes("select-customizations"),
        `${id} names the replacement transformer`
      );
      assert.false(
        /select-content|select-on-change/.test(fired?.message ?? ""),
        `${id} no longer names a removed transformer`
      );
    }
  });

  test("reconstructs the legacy (component, value, item) onChange signature", function (assert) {
    let received:
      | { component: LegacyComponentFacade; value: unknown; item: unknown }
      | undefined;
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .onChange(
          (component: LegacyComponentFacade, value: unknown, item: unknown) => {
            received = { component, value, item };
          }
        );
    });

    const engine = engineFor(getOwner(this), {
      items: [{ id: 7, name: "Seven" }],
    });
    engine.select({ id: 7, name: "Seven" });

    assert.strictEqual(received?.value, 7, "the value id is passed");
    assert.deepEqual(
      received?.item,
      { id: 7, name: "Seven" },
      "a single item (not an array) is passed for single-select"
    );
    assert.strictEqual(
      typeof received?.component.selectKit.close,
      "function",
      "the component facade carries a selectKit surface"
    );
  });

  test("an injected action row's onSelect runs with the selectKit facade, not the engine", function (assert) {
    let receivedFirstArg: LegacyComponentFacade["selectKit"] | undefined;
    withPluginApi((api) => {
      api.modifySelectKit("test-select").prependContent(() => ({
        id: "action",
        name: "Do something",
        onSelect: (selectKit: LegacyComponentFacade["selectKit"]) =>
          (receivedFirstArg = selectKit),
      }));
    });

    const engine = engineFor(getOwner(this));
    const actionRows = engine
      .buildItems([])
      .filter((descriptor) => descriptor.value === "action");
    assert.strictEqual(
      actionRows.length,
      1,
      "the injected action row is built"
    );

    // `activate` takes the raw model: `onSelect` lives there, not on the descriptor.
    engine.activate(actionRows[0].item);

    assert.notStrictEqual(
      receivedFirstArg,
      engine,
      "the engine is not leaked to a legacy onSelect"
    );
    assert.strictEqual(
      typeof receivedFirstArg?.select,
      "function",
      "the legacy selectKit facade is passed instead"
    );
    assert.strictEqual(
      typeof (receivedFirstArg as { set?: unknown } | undefined)?.set,
      "function",
      "it is the facade, which only the legacy surface has a setter on"
    );
  });

  test("the facade exposes a resolvable owner and a live element", function (assert) {
    let sawOwner: Owner | undefined;
    let sawElement: HTMLElement | undefined;
    const element = document.createElement("section");
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent((component: LegacyComponentFacade) => {
          sawOwner = getOwner(component);
          sawElement = component.element;
        });
    });

    const engine = new SelectEngine({
      kind: "test-select",
      items: [],
      getValue: () => null,
      legacy: {
        owner: getOwner(this),
        getElement: () => element,
        isDestroyed: () => false,
      },
    });
    engine.buildItems([]);

    assert.strictEqual(
      sawOwner,
      getOwner(this),
      "getOwner(component) resolves"
    );
    assert.strictEqual(
      sawElement,
      element,
      "component.element is the live element"
    );
  });

  test("reuses one stable facade across renders", function (assert) {
    const seen = new Set();
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent((component: LegacyComponentFacade) => {
          seen.add(component);
          return { id: "x", name: "X" };
        });
    });

    const engine = engineFor(getOwner(this));
    engine.buildItems([]);
    engine.buildItems([]);

    assert.strictEqual(seen.size, 1, "the same facade instance is reused");
  });

  test("the facade survives a runtime multiple flip (engine identity is stable)", function (assert) {
    const seen = new Set();
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent((component: LegacyComponentFacade) => {
          seen.add(component);
          return { id: "x", name: "X" };
        });
    });

    let multiple = false;
    const element = document.createElement("div");
    const engine = new SelectEngine({
      kind: "test-select",
      items: [],
      getMultiple: () => multiple,
      getValue: () => (multiple ? [] : null),
      legacy: {
        owner: getOwner(this),
        getElement: () => element,
        isDestroyed: () => false,
      },
    });

    engine.buildItems([]);
    multiple = true;
    engine.buildItems([]);

    assert.true(engine.multiple, "the flip is live on the engine");
    assert.strictEqual(
      seen.size,
      1,
      "the same facade instance is reused across the flip"
    );
  });

  test("emits the content deprecation once per engine instance", async function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent(() => ({ id: "x", name: "X" }));
    });

    const engine = engineFor(getOwner(this));
    engine.buildItems([]);
    engine.buildItems([]);
    await settled();

    assert.strictEqual(
      firedFor(CONTENT_ID).length,
      1,
      "the bridge warns once, not per render"
    );

    engineFor(getOwner(this)).buildItems([]);
    await settled();

    assert.strictEqual(
      firedFor(CONTENT_ID).length,
      2,
      "another control warns again"
    );
  });

  test("attributes each deprecation to the plugin that registered the callback", async function (assert) {
    withPluginApi(
      (api) => api.modifySelectKit("test-select").appendContent(() => {}),
      pluginOpts("bridge-plugin-a")
    );
    withPluginApi(
      (api) => api.modifySelectKit("test-select").prependContent(() => {}),
      pluginOpts("bridge-plugin-b")
    );

    const engine = engineFor(getOwner(this));
    engine.buildItems([]);
    engine.buildItems([]);
    await settled();

    assert.deepEqual(
      firedFor(CONTENT_ID)
        .map((fired) => fired.source?.name)
        .sort(),
      ["bridge-plugin-a", "bridge-plugin-b"],
      "one per registering plugin, even when the callbacks return nothing"
    );
  });

  test("a chained registration keeps its plugin", async function (assert) {
    withPluginApi(
      (api) =>
        api
          .modifySelectKit("test-select")
          .prependContent(() => {})
          .onChange(() => {}),
      pluginOpts("bridge-plugin-chain")
    );

    const engine = engineFor(getOwner(this), {
      items: [{ id: 1, name: "One" }],
    });
    engine.select({ id: 1, name: "One" });
    await settled();

    assert.deepEqual(
      firedFor(ON_CHANGE_ID).map((fired) => fired.source?.name),
      ["bridge-plugin-chain"],
      "the onChange registered further down the chain is attributed"
    );
  });

  test("a callback registered by core is still reported, unattributed", async function (assert) {
    withPluginApi((api) => {
      api.modifySelectKit("test-select").appendContent(() => {});
    });

    engineFor(getOwner(this)).buildItems([]);
    await settled();

    assert.strictEqual(firedFor(CONTENT_ID).length, 1, "it is reported");
    assert.strictEqual(
      firedFor(CONTENT_ID)[0].source,
      undefined,
      "with no plugin named"
    );
  });

  test("does not warn or fire when no legacy callbacks are registered", async function (assert) {
    const engine = engineFor(getOwner(this));
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(ids(items), ["core"], "content is untouched");
    await settled();
    assert.strictEqual(
      firedDeprecations.length,
      0,
      "no deprecation is emitted when the bridge is inert"
    );
  });

  test("setting isLoading again holds the same update until it is cleared", async function (assert) {
    let facade: LegacyComponentFacade | undefined;
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent((component: LegacyComponentFacade) => {
          facade = component;
        });
    });
    const engine = engineFor(getOwner(this));
    engine.buildItems([]);
    const updates = sinon.spy(engine, "update");

    facade!.selectKit.set("isLoading", true);
    facade!.selectKit.set("isLoading", true);
    assert.strictEqual(updates.callCount, 1, "one update is started");
    assert.true(engine.pending, "the held update drives the pending state");

    facade!.selectKit.set("isLoading", false);
    await settled();
    assert.false(engine.pending, "clearing it ends the pending state");

    facade!.selectKit.set("isLoading", true);
    assert.strictEqual(updates.callCount, 2, "a later start holds a new one");
    facade!.selectKit.set("isLoading", false);
    await settled();
  });

  test("a change customization wraps the controlled onChange", function (assert) {
    let context: { value: unknown } | undefined;
    let changedTo: unknown;
    withPluginApi((api) => {
      api.registerValueTransformer<SelectCustomizationRegistry>(
        "select-customizations",
        ({ value: selects }) =>
          selects.forAll((spec) =>
            spec.change((next, ctx) => {
              context = ctx;
              next();
            })
          )
      );
    });

    const engine = new SelectEngine({
      items: [{ id: 3, name: "Three" }],
      getValue: () => null,
      onChange: (value) => (changedTo = value),
    });
    engine.select({ id: 3, name: "Three" });

    assert.strictEqual(
      context?.value,
      3,
      "the transformer sees the next value"
    );
    assert.strictEqual(changedTo, 3, "next() runs the default onChange");
  });
});

module(
  "Unit | ui-kit | modify-select-kit bridge | sticky leading content",
  function (hooks) {
    setupTest(hooks);
    setupLegacyBridgeCallbacks(hooks);

    test("hoists prepended and appended actions after content transformation in stable order", function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer<SelectCustomizationRegistry>(
          "select-customizations",
          ({ value: selects }) =>
            selects.forAll((spec) =>
              spec.content((items) => [
                ...items,
                { id: "native", name: "Native", sticky: true },
              ])
            )
        );
        api
          .modifySelectKit("sticky-select")
          .prependContent(() => ({ id: "pre", name: "Prepend", sticky: true }));
        api
          .modifySelectKit("sticky-select")
          .appendContent(() => ({ id: "post", name: "Append", sticky: true }));
      });
      const element = document.createElement("div");
      const engine = new SelectEngine({
        kind: "sticky-select",
        getOptions: () => ({ noneRow: true }),
        specialItems: () => [{ id: "special", name: "Special", sticky: true }],
        legacy: {
          owner: getOwner(this),
          getElement: () => element,
          isDestroyed: () => false,
        },
      });
      const rows = engine.buildItems([{ id: "core", name: "Core" }]);
      assert.deepEqual(
        ids(rows),
        ["special", "pre", "native", "post", null, "core"],
        "specials and bridge output retain their pre-hoist order"
      );
      assert.deepEqual(
        rows.map((row) => row.flags.sticky),
        [true, true, true, true, false, false],
        "bridge actions carry the sticky descriptor flag"
      );
    });
  }
);
