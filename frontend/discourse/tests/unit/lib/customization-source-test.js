import { module, test } from "qunit";
import {
  CORE_SOURCE,
  resolveSourceId,
} from "discourse/lib/customization-source";

module("Unit | Lib | customization-source", function () {
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
});
