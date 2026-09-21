import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import NodePanel from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/node-panel";
import packNodeTypes from "../../../fixtures/node-pack-node-types";

module(
  "Integration | Component | Workflows | Canvas | NodePanel",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("renders imported pack metadata and management links", async function (assert) {
      this.set("nodeTypes", packNodeTypes);

      await render(
        <template>
          <NodePanel @nodeTypes={{this.nodeTypes}} @searchTerm="" />
        </template>
      );

      assert
        .dom(".workflows-node-panel__category-name")
        .hasText("Example pack");
      assert
        .dom(
          ".workflows-node-panel__category .workflows-node-panel__imported-badge"
        )
        .hasText("Imported · v1.2.0");
      assert
        .dom(".workflows-node-panel__footer a")
        .exists(
          { count: 2 },
          "pack management links render even before selecting a pack"
        );

      await click(".workflows-node-panel__category");

      assert.dom(".workflows-node-panel__item").exists({ count: 4 });
      assert
        .dom(".workflows-node-panel__item-name")
        .hasText("Check a statement");
      assert
        .dom(".workflows-node-panel__item-description")
        .hasText("Check · Probability a statement is true");
      assert
        .dom(".workflows-node-panel__item img")
        .doesNotExist("literal metadata cannot inject markup");
    });
  }
);
