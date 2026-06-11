import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module(
  "Unit | Route | admin-plugins.discourse-subscriptions.products.index",
  function (hooks) {
    setupTest(hooks);

    test("returns the unconfigured model from the products endpoint", async function (assert) {
      pretender.get("/s/admin/products", () => response(null));

      const route = this.owner.lookup(
        "route:admin-plugins.discourse-subscriptions.products.index"
      );
      const model = await route.model();

      assert.deepEqual(
        model,
        { unconfigured: true },
        "the template can render the unconfigured state"
      );
    });
  }
);
