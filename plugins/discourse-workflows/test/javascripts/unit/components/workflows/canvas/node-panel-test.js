import { module, test } from "qunit";
import {
  nodeTypesForPalette,
  sortNodeTypesByLabel,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/node-panel";

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

  test("excludes non-palette executable node types", function (assert) {
    const visible = nodeTypesForPalette([
      { identifier: "action:user" },
      { identifier: "flow:loop_over_items", palette_visible: false },
      { identifier: "action:unavailable", available: false },
    ]);

    assert.deepEqual(
      visible.map((nodeType) => nodeType.identifier),
      ["action:user"],
      "keeps hidden executable definitions out of search and categories"
    );
  });
});
