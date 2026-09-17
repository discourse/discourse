import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  SEARCH_TYPE_CATS_TAGS,
  SEARCH_TYPE_DEFAULT,
  SEARCH_TYPE_USERS,
} from "discourse/controllers/full-page-search";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Unit | Controller | full-page-search", function (hooks) {
  setupTest(hooks);

  test("counts results for the selected search type", async function (assert) {
    const controller = this.owner.lookup("controller:full-page-search");
    controller.set("model", {
      posts: [],
      categories: [],
      tags: [],
      users: [{ id: 1 }, { id: 2 }],
    });
    controller.addSearchResults([{ id: 1, topic_id: 1 }], "topic_id");
    await settled();

    assert.strictEqual(
      controller.resultCount,
      3,
      "Posts includes supplemental results"
    );

    controller.setSearchType(SEARCH_TYPE_USERS);
    await settled();
    assert.strictEqual(
      controller.resultCount,
      2,
      "Users counts only matching users"
    );

    controller.set("model.users", []);
    await settled();
    assert.strictEqual(
      controller.resultCount,
      0,
      "Users excludes supplemental posts when empty"
    );
    assert.false(controller.hasResults, "Users shows the empty state");

    controller.set("model.categories", [{ id: 1 }]);
    controller.set("model.tags", [{ id: 1 }]);
    controller.setSearchType(SEARCH_TYPE_CATS_TAGS);
    await settled();
    assert.strictEqual(
      controller.resultCount,
      2,
      "Categories and tags excludes supplemental posts"
    );

    controller.setSearchType(SEARCH_TYPE_DEFAULT);
    await settled();
    assert.strictEqual(
      controller.resultCount,
      3,
      "Posts includes supplemental results again"
    );
  });

  test("full-page-search-load-more behavior transformer", function (assert) {
    withPluginApi((api) => {
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
