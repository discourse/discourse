import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { registerDeprecationHandler } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "discourse/select-kit/lib/plugin-api";
import {
  resetLegacyBridge,
  suppressLegacyBridge,
} from "discourse/ui-kit/select/-internals/modify-select-kit-bridge";
import SelectEngine from "discourse/ui-kit/select/select-engine";

// One deprecation handler for the whole module, recording every fired id, so tests can
// assert the bridge's per-instance deprecation without leaking a handler per test.
const firedDeprecations = [];
let handlerRegistered = false;

function ids(items) {
  return items.map((item) => item.id);
}

module("Unit | ui-kit | modify-select-kit bridge", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    firedDeprecations.length = 0;
    if (!handlerRegistered) {
      registerDeprecationHandler((_message, options) =>
        firedDeprecations.push(options?.id)
      );
      handlerRegistered = true;
    }
  });

  hooks.afterEach(function () {
    clearCallbacks();
    resetLegacyBridge();
  });

  // Builds an engine wired for the bridge with a resolvable owner and a live element.
  function engineFor(owner, opts = {}) {
    const element = document.createElement("div");
    return new SelectEngine({
      identifiers: opts.identifiers ?? ["test-select"],
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

  test("fans out across the identifier array (a base-identifier callback fires)", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("combo-box")
        .appendContent(() => ({ id: "base", name: "From base" }));
      api
        .modifySelectKit("unrelated")
        .appendContent(() => ({ id: "nope", name: "Should not fire" }));
    });

    const engine = engineFor(getOwner(this), {
      identifiers: ["combo-box", "category-chooser"],
    });
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.true(
      ids(items).includes("base"),
      "the base-identifier row is added"
    );
    assert.false(
      ids(items).includes("nope"),
      "an unrelated identifier's callback does not fire"
    );
  });

  test("reconstructs the legacy (component, value, item) onChange signature", function (assert) {
    let received;
    withPluginApi((api) => {
      api.modifySelectKit("test-select").onChange((component, value, item) => {
        received = { component, value, item };
      });
    });

    const engine = engineFor(getOwner(this), {
      items: [{ id: 7, name: "Seven" }],
    });
    engine.select({ id: 7, name: "Seven" });

    assert.strictEqual(received.value, 7, "the value id is passed");
    assert.deepEqual(
      received.item,
      { id: 7, name: "Seven" },
      "a single item (not an array) is passed for single-select"
    );
    assert.strictEqual(
      typeof received.component.selectKit.close,
      "function",
      "the component facade carries a selectKit surface"
    );
  });

  test("an injected action row's onSelect runs with the selectKit facade, not the engine", function (assert) {
    let receivedFirstArg;
    withPluginApi((api) => {
      api.modifySelectKit("test-select").prependContent(() => ({
        id: "action",
        name: "Do something",
        onSelect: (selectKit) => (receivedFirstArg = selectKit),
      }));
    });

    const engine = engineFor(getOwner(this));
    const actionRow = engine.buildItems([]).find((i) => i.id === "action");
    engine.activate(actionRow);

    assert.notStrictEqual(
      receivedFirstArg,
      engine,
      "the engine is not leaked to a legacy onSelect"
    );
    assert.strictEqual(
      typeof receivedFirstArg.select,
      "function",
      "the legacy selectKit facade is passed instead"
    );
  });

  test("the facade exposes a resolvable owner and a live element", function (assert) {
    let sawOwner, sawElement;
    const element = document.createElement("section");
    withPluginApi((api) => {
      api.modifySelectKit("test-select").appendContent((component) => {
        sawOwner = getOwner(component);
        sawElement = component.element;
      });
    });

    const engine = new SelectEngine({
      identifiers: ["test-select"],
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
      api.modifySelectKit("test-select").appendContent((component) => {
        seen.add(component);
        return { id: "x", name: "X" };
      });
    });

    const engine = engineFor(getOwner(this));
    engine.buildItems([]);
    engine.buildItems([]);

    assert.strictEqual(seen.size, 1, "the same facade instance is reused");
  });

  test("suppressed identifiers are not bridged (no double-insert with a native path)", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent(() => ({ id: "legacy", name: "Legacy" }));
    });
    // Simulate the identifier having opted into a native select-content transformer.
    suppressLegacyBridge("test-select");

    const engine = engineFor(getOwner(this));
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(
      ids(items),
      ["core"],
      "the legacy callback is skipped for a suppressed identifier"
    );
  });

  test("emits the content deprecation once per engine instance", function (assert) {
    withPluginApi((api) => {
      api
        .modifySelectKit("test-select")
        .appendContent(() => ({ id: "x", name: "X" }));
    });

    const engine = engineFor(getOwner(this));
    engine.buildItems([]);
    engine.buildItems([]);

    const contentDeprecations = firedDeprecations.filter(
      (id) => id === "discourse.select-kit.modify-select-kit-content"
    );
    assert.strictEqual(
      contentDeprecations.length,
      1,
      "the bridge warns once, not per render"
    );
  });

  test("does not warn or fire when no legacy callbacks are registered", function (assert) {
    const engine = engineFor(getOwner(this));
    const items = engine.buildItems([{ id: "core", name: "Core" }]);

    assert.deepEqual(ids(items), ["core"], "content is untouched");
    assert.strictEqual(
      firedDeprecations.length,
      0,
      "no deprecation is emitted when the bridge is inert"
    );
  });

  test("select-on-change behavior transformer wraps the controlled onChange", function (assert) {
    let context;
    let changedTo;
    withPluginApi((api) => {
      api.registerBehaviorTransformer(
        "select-on-change",
        ({ context: ctx, next }) => {
          context = ctx;
          next();
        }
      );
    });

    const engine = new SelectEngine({
      items: [{ id: 3, name: "Three" }],
      getValue: () => null,
      onChange: (value) => (changedTo = value),
    });
    engine.select({ id: 3, name: "Three" });

    assert.strictEqual(context.value, 3, "the transformer sees the next value");
    assert.strictEqual(changedTo, 3, "next() runs the default onChange");
  });
});
