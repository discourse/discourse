import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import FeaturedTags from "discourse/blocks/builtin/featured-tags";
import FeaturedUsers from "discourse/blocks/builtin/featured-users";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Blocks | featured data", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    resetBlockData();
  });

  module("featured-tags", function () {
    test("renders a tag per resolved tag", async function (assert) {
      pretender.get("/tags.json", () =>
        response({
          tags: [
            { id: 1, name: "alpha", count: 5 },
            { id: 2, name: "beta", count: 3 },
          ],
        })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: FeaturedTags, args: {} }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-tags__list");
      await settled();

      assert
        .dom(".d-block-featured-tags__list .discourse-tag")
        .exists({ count: 2 }, "renders one tag element per resolved tag");
      assert
        .dom(".d-block-featured-tags__empty")
        .doesNotExist("no empty state when tags resolve");
    });

    test("renders the empty state when no tags resolve", async function (assert) {
      pretender.get("/tags.json", () => response({ tags: [] }));

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: FeaturedTags, args: {} }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-tags__empty");
      await settled();

      assert
        .dom(".d-block-featured-tags__empty")
        .exists("the empty branch renders for an empty tag list");
      assert
        .dom(".d-block-featured-tags__list")
        .doesNotExist("no list when there are no tags");
    });
  });

  module("featured-users", function () {
    test("renders an item per resolved contributor", async function (assert) {
      pretender.get("/directory_items", () =>
        response({
          directory_items: [
            {
              id: 1,
              likes_received: 100,
              user: {
                id: 1,
                username: "alice",
                avatar_template: "/images/avatar.png",
              },
            },
            {
              id: 2,
              likes_received: 50,
              user: {
                id: 2,
                username: "bob",
                avatar_template: "/images/avatar.png",
              },
            },
          ],
          meta: {
            total_rows_directory_items: 2,
            load_more_directory_items: null,
          },
        })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: FeaturedUsers, args: {} }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-users__list");
      await settled();

      assert
        .dom(".d-block-featured-users__item")
        .exists({ count: 2 }, "renders one item per resolved contributor");
      assert
        .dom(".d-block-featured-users__list")
        .includesText("alice", "renders the first contributor's name")
        .includesText("bob", "renders the second contributor's name");
    });

    test("renders the empty state when the directory is empty", async function (assert) {
      pretender.get("/directory_items", () =>
        response({
          directory_items: [],
          meta: {
            total_rows_directory_items: 0,
            load_more_directory_items: null,
          },
        })
      );

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: FeaturedUsers, args: {} }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-users__empty");
      await settled();

      assert
        .dom(".d-block-featured-users__empty")
        .exists("the empty branch renders for an empty directory");
      assert
        .dom(".d-block-featured-users__list")
        .doesNotExist("no list when the directory is empty");
    });
  });
});
