import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  clearDevTools,
  devToolsDAG,
  LAST_CORE_TOOL,
} from "discourse/lib/dev-tools/registry";

function keysInOrder() {
  return devToolsDAG()
    .resolve()
    .map(({ key }) => key);
}

/**
 * Adds tools the way the developer tools entrypoint does: each one positioned
 * explicitly after the previous, rather than relying on insertion order.
 */
function seedCoreLike(ids) {
  let previous;

  for (const id of ids) {
    devToolsDAG().add(
      id,
      `${id}-component`,
      previous ? { after: previous } : {}
    );
    previous = id;
  }
}

module("Unit | Lib | dev-tools | registry", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    clearDevTools();
  });

  test("resolves tools in the order established by their positions", function (assert) {
    seedCoreLike(["first", "second", "third"]);

    assert.deepEqual(keysInOrder(), ["first", "second", "third"]);
  });

  test("a tool registered before the core tools exist still sorts after them", function (assert) {
    // Application initializers run synchronously during boot, while the
    // developer tools chunk arrives later, so anything registered through the
    // plugin API is added before the core tools are. The anchor it defaults to
    // does not exist yet at that point.
    devToolsDAG().add("from-a-plugin", "plugin-component");

    seedCoreLike([
      "plugin-outlet-debug",
      "block-debug",
      "upcoming-changes-debug",
      "safe-mode",
      LAST_CORE_TOOL,
    ]);

    assert.deepEqual(
      keysInOrder(),
      [
        "plugin-outlet-debug",
        "block-debug",
        "upcoming-changes-debug",
        "safe-mode",
        LAST_CORE_TOOL,
        "from-a-plugin",
      ],
      "the core tools keep their order and the plugin tool follows them"
    );
  });

  test("a tool can still position itself among the core tools", function (assert) {
    devToolsDAG().add("from-a-plugin", "plugin-component", {
      before: "block-debug",
    });

    seedCoreLike(["plugin-outlet-debug", "block-debug", LAST_CORE_TOOL]);

    const keys = keysInOrder();

    // Only the constraint that was asked for is guaranteed. A tool declaring
    // just `before` is not thereby placed after whatever preceded its anchor,
    // so it may appear ahead of earlier core tools; declare `after` as well to
    // pin it between two of them.
    assert.true(
      keys.indexOf("from-a-plugin") < keys.indexOf("block-debug"),
      "the tool is placed before its anchor"
    );
    assert.true(
      keys.indexOf("plugin-outlet-debug") < keys.indexOf("block-debug"),
      "the core tools keep their relative order"
    );
    assert.true(
      keys.indexOf("block-debug") < keys.indexOf(LAST_CORE_TOOL),
      "the core tools keep their relative order"
    );
  });

  test("seeding twice leaves the registry unchanged", function (assert) {
    const ids = ["plugin-outlet-debug", "block-debug", LAST_CORE_TOOL];

    seedCoreLike(ids);
    seedCoreLike(ids);

    assert.deepEqual(keysInOrder(), ids, "no tool is duplicated");
  });

  test("registering an existing key does not replace the tool", function (assert) {
    devToolsDAG().add("block-debug", "original");

    assert.false(
      devToolsDAG().add("block-debug", "replacement"),
      "reports that nothing was added"
    );
    assert.strictEqual(
      devToolsDAG().resolve()[0].value,
      "original",
      "keeps the tool that was registered first"
    );
  });

  test("clearing empties the registry", function (assert) {
    seedCoreLike(["plugin-outlet-debug", "block-debug"]);

    clearDevTools();

    assert.deepEqual(keysInOrder(), []);
  });
});
