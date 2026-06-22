import { module, test } from "qunit";
import {
  CORE_SOURCE,
  isCustomizationSource,
  resolveSourceId,
  SOURCE_BRAND,
  splitSourceArgs,
} from "discourse/lib/customization-source";

function branded(descriptor) {
  return { [SOURCE_BRAND]: true, ...descriptor };
}

module("Unit | Lib | customization-source", function () {
  test("SOURCE_BRAND matches the key the build transform emits", function (assert) {
    // The inject-customization-source babel transform hardcodes this registry
    // key (its own test pins the emitted `Symbol.for(...)`). This assertion pins
    // the runtime side so the two cannot drift silently.
    assert.strictEqual(
      SOURCE_BRAND.description,
      "discourse:customization-source"
    );
  });

  test("CORE_SOURCE is a frozen core descriptor", function (assert) {
    assert.deepEqual(CORE_SOURCE, { type: "core" });
    assert.true(Object.isFrozen(CORE_SOURCE));
  });

  test("resolveSourceId maps descriptors to stable ids", function (assert) {
    assert.strictEqual(
      resolveSourceId({ type: "plugin", name: "chat" }),
      "plugin:chat"
    );
    assert.strictEqual(resolveSourceId({ type: "theme", id: 42 }), "theme:42");
    assert.strictEqual(resolveSourceId(CORE_SOURCE), null, "core has no id");
    assert.strictEqual(resolveSourceId(null), null);
    assert.strictEqual(resolveSourceId(undefined), null);
  });

  test("isCustomizationSource only matches a branded descriptor", function (assert) {
    assert.true(
      isCustomizationSource(branded({ type: "plugin", name: "chat" }))
    );
    assert.false(isCustomizationSource({ type: "plugin", name: "chat" }));
    assert.false(isCustomizationSource({ foo: 1 }));
    assert.false(isCustomizationSource(null));
    assert.false(isCustomizationSource(undefined));
  });

  test("splitSourceArgs separates source from callback/opts across call shapes", function (assert) {
    const cb = () => {};
    const opts = { foo: 1 };
    const source = branded({ type: "plugin", name: "chat" });

    let result = splitSourceArgs([cb]);
    assert.strictEqual(result.apiCodeCallback, cb, "callback-only: callback");
    assert.strictEqual(result.opts, undefined, "callback-only: no opts");
    assert.strictEqual(result.source, undefined, "callback-only: no source");

    result = splitSourceArgs([cb, opts]);
    assert.strictEqual(result.opts, opts, "callback + opts: opts preserved");
    assert.strictEqual(result.source, undefined);

    result = splitSourceArgs([cb, opts, source]);
    assert.strictEqual(result.apiCodeCallback, cb, "with descriptor: callback");
    assert.strictEqual(result.opts, opts, "with descriptor: opts preserved");
    assert.strictEqual(
      result.source,
      source,
      "with descriptor: source stripped"
    );

    result = splitSourceArgs(["1.0", cb, opts, source]);
    assert.strictEqual(
      result.apiCodeCallback,
      cb,
      "legacy version string is dropped"
    );
    assert.strictEqual(result.opts, opts);
    assert.strictEqual(result.source, source);
  });
});
