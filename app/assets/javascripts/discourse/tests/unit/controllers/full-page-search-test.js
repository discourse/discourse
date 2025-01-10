import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Unit | Controller | full-page-search", function (hooks) {
  setupTest(hooks);

  test("full-page-search-load-more behavior transformer", function (assert) {
    withPluginApi("2.0.0", (api) => {
      const controller = this.owner.lookup("controller:full-page-search");
      controller.model = {
        grouped_search_result: { more_full_page_results: true },
      };

      api.registerBehaviorTransformer(
        "full-page-search-load-more",
        ({ next }) => {
          if (controller.blockWithTransformer) {
            return;
          }
          next();
        }
      );

      assert.strictEqual(controller.page, 1);

      controller.loadMore();
      assert.strictEqual(controller.page, 2);

      // Block loading by setting variable on controller which transformer sees
      controller.blockWithTransformer = true;
      controller.loadMore();
      assert.strictEqual(controller.page, 2);

      // Now unblock and ensure next() functions
      controller.blockWithTransformer = false;
      controller.loadMore();
      assert.strictEqual(controller.page, 3);
    });
  });
});
