import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module(
  "Unit | Route | admin-plugins/show/discourse-ai-models",
  function (hooks) {
    setupTest(hooks);

    test("loads decision models with workflows disabled", async function (assert) {
      this.owner.lookup("service:site-settings").enable_discourse_workflows =
        false;
      const route = this.owner.lookup(
        "route:admin-plugins/show/discourse-ai-models"
      );
      const findAll = sinon.stub(route.store, "findAll");
      const empty = { content: [], resultSetMeta: { presets: [] } };
      findAll.resolves(empty);

      const model = await route.model();

      assert.deepEqual(
        findAll.args,
        [["ai-llm"], ["ai-embedding"], ["ai-decision-model"]],
        "loads every model type regardless of workflow availability"
      );
      assert.strictEqual(
        model.decisionModels,
        empty,
        "keeps the empty result and its creation presets"
      );
    });
  }
);
