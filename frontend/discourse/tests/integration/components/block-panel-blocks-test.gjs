import { hash } from "@ember/helper";
import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import BlockCategoryNavigation from "discourse/blocks/builtin/block-category-navigation";
import BlockResources from "discourse/blocks/builtin/block-resources";
import FeaturedTopics from "discourse/blocks/builtin/featured-topics";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { cloneJSON } from "discourse/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

// A real topic list response, trimmed to two topics.
function topicList() {
  const list = cloneJSON(discoveryFixtures["/latest.json"]);
  list.topic_list.topics = list.topic_list.topics.slice(0, 2);
  return list;
}

module("Integration | Blocks | panel blocks", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    resetBlockData();
  });

  module("featured-topics", function () {
    test("renders topics in a panel with a view all link", async function (assert) {
      pretender.get("/hot.json", () => response(topicList()));

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: FeaturedTopics, args: { title: "Hot", count: 2 } },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-topics__list");
      await settled();

      assert
        .dom(".d-block-featured-topics .d-block-panel__title")
        .hasText("Hot");
      assert
        .dom(".d-block-featured-topics__item")
        .exists({ count: 2 }, "one row per topic");
      assert
        .dom(".d-block-featured-topics .d-block-panel__link")
        .hasAttribute("href", "/hot", "view all opens the same list");
    });

    test("sorts the list and keeps the order in the view all link", async function (assert) {
      let requestedOrder;
      pretender.get("/latest.json", (request) => {
        requestedOrder = request.queryParams.order;
        return response(topicList());
      });

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: FeaturedTopics,
            args: { filter: "latest", order: "likes" },
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      await waitFor(".d-block-featured-topics__list");
      await settled();

      assert.strictEqual(
        requestedOrder,
        "likes",
        "the list is requested sorted"
      );
      assert
        .dom(".d-block-featured-topics .d-block-panel__link")
        .hasAttribute("href", "/latest?order=likes");
    });

    test("follows the top-level category of the current page", async function (assert) {
      const site = this.owner.lookup("service:site");
      const parent = site.categories.find((c) => c.subcategories?.length);
      const child = parent.subcategories[0];
      const path = `/c/${parent.slug}/${parent.id}/l/hot.json`;
      pretender.get(path, () => response(topicList()));

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: FeaturedTopics, args: { currentCategory: true } },
        ])
      );

      await render(
        <template>
          <BlockOutlet
            @name="hero-blocks"
            @outletArgs={{hash category=child}}
          />
        </template>
      );
      await waitFor(".d-block-featured-topics__list");
      await settled();

      assert
        .dom(".d-block-featured-topics .d-block-panel__link")
        .hasAttribute(
          "href",
          `/c/${parent.slug}/${parent.id}/l/hot`,
          "a subcategory page lists its top-level category"
        );
    });
  });

  module("category-navigation", function () {
    test("lists the top-level categories on lists without a category", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: BlockCategoryNavigation }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".d-block-category-navigation.--global .d-block-panel__title")
        .hasText("Categories");
      assert.dom(".d-block-category-navigation__link").exists();
    });

    test("shows the top-level category with its subcategories", async function (assert) {
      const site = this.owner.lookup("service:site");
      const parent = site.categories.find((c) => c.subcategories?.length);
      const child = parent.subcategories[0];
      const discovery = this.owner.lookup("service:discovery");
      sinon.stub(discovery, "category").get(() => child);

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: BlockCategoryNavigation }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".d-block-category-navigation__head")
        .includesText(parent.displayName, "the header names the top level");
      assert
        .dom(".d-block-category-navigation__item.--current")
        .includesText(child.displayName, "the current subcategory is marked");
    });
  });

  module("resources", function () {
    test("renders complete links and skips incomplete ones", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockResources,
            args: {
              links: [
                { label: "Guidelines", url: "/guidelines", icon: "book" },
                { label: "Docs", url: "https://example.com/docs" },
                { label: "", url: "", icon: "", description: "" },
              ],
            },
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".d-block-resources__link")
        .exists({ count: 2 }, "the empty link is left out");
      assert
        .dom(".d-block-resources__item:nth-child(2) .d-block-resources__link")
        .hasAttribute("target", "_blank", "external links open a new tab");
    });

    test("renders nothing without a complete link", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockResources,
            args: {
              links: [{ label: "", url: "", icon: "", description: "" }],
            },
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".d-block-resources").doesNotExist();
    });
  });
});
