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

  module("frame styles", function (innerHooks) {
    innerHooks.beforeEach(function () {
      pretender.get("/directory_items", () =>
        response({
          directory_items: [
            {
              id: 1,
              user: { id: 1, username: "alice", avatar_template: "/a.png" },
            },
            {
              id: 2,
              user: { id: 2, username: "bob", avatar_template: "/a.png" },
            },
          ],
        })
      );
    });

    async function renderUsers(args) {
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: FeaturedUsers, args: { title: "Members", ...args } },
        ])
      );
      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-users__list");
      await settled();
    }

    test("plain keeps the block's own title and no frame", async function (assert) {
      await renderUsers({ frameStyle: "plain", linkHref: "/u" });

      assert.dom(".d-block-frame").doesNotExist();
      assert.dom(".d-block-featured-users__title").hasText("Members");
      assert
        .dom(".d-block-frame__link")
        .doesNotExist("the link is only drawn by a frame");
    });

    test("panel draws an icon header, divided rows and a show all footer", async function (assert) {
      await renderUsers({ frameStyle: "panel", linkHref: "/u" });

      assert
        .dom(".d-block-frame.--panel .d-block-frame__header .d-icon-users")
        .exists("the default icon heads the panel");
      assert.dom(".d-block-frame__header h3").hasText("Members");
      assert
        .dom(".d-block-featured-users__title")
        .doesNotExist("the block's own title gives way to the frame's");
      assert
        .dom(".d-block-frame__body .d-block-frame__content")
        .exists("the block body sits in the frame");
      assert
        .dom(".d-block-frame__row")
        .exists({ count: 2 }, "each contributor is a frame row");
      assert
        .dom(".d-block-frame__footer .d-block-frame__link")
        .hasAttribute("href", "/u")
        .hasText("Show all");
    });

    test("heading puts the title and link above the rows", async function (assert) {
      await renderUsers({
        frameStyle: "heading",
        linkLabel: "Member directory",
        linkHref: "/u",
      });

      assert
        .dom(".d-block-frame.--heading .d-block-frame__header h2")
        .hasText("Members");
      assert
        .dom(".d-block-frame__header .d-block-frame__link")
        .hasAttribute("href", "/u")
        .hasText("Member directory");
      assert.dom(".d-block-frame__icon").doesNotExist("headings have no icon");
      assert.dom(".d-block-frame__footer").doesNotExist();
    });
  });
});
