import { module, test } from "qunit";
import { sortNodeTypesByLabel } from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/node-panel";

module("Unit | Component | Workflows | Canvas | NodePanel", function () {
  test("sorts node types by translated label", function (assert) {
    const sorted = sortNodeTypesByLabel([
      { identifier: "action:user" },
      { identifier: "action:send_chat_message" },
      { identifier: "action:badge" },
    ]);

    assert.deepEqual(
      sorted.map((nodeType) => nodeType.identifier),
      ["action:badge", "action:send_chat_message", "action:user"],
      "the node panel order is alphabetical by label"
    );
  });
});
