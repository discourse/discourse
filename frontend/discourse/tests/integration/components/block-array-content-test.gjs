import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import LinkList from "discourse/blocks/builtin/link-list";
import List from "discourse/blocks/builtin/list";
import Stats from "discourse/blocks/builtin/stats";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | array content", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("link-list renders each item as a link with an optional icon", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: LinkList,
          args: {
            items: [
              {
                label: "Docs",
                url: "/docs",
                icon: "book",
                description: "Read the guides",
              },
              { label: "API", url: "/api" },
            ],
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-link-list__link")
      .exists({ count: 2 }, "renders a link per item");
    assert
      .dom(".d-block-link-list__item:first-child .d-block-link-list__link")
      .hasAttribute("href", "/docs");
    assert
      .dom(".d-block-link-list__item:first-child .d-block-inline-icon")
      .exists("renders the icon when one is set");
    assert
      .dom(".d-block-link-list__item:last-child .d-block-inline-icon")
      .doesNotExist("omits the icon when none is set");
    assert
      .dom(
        ".d-block-link-list__item:first-child .d-block-link-list__description"
      )
      .hasText("Read the guides", "renders the per-item description when set");
    assert
      .dom(
        ".d-block-link-list__item:last-child .d-block-link-list__description"
      )
      .doesNotExist("omits the description when none is set");
  });

  test("stats renders value/label items and links the ones with an href", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Stats,
          args: {
            items: [
              { value: "1.2k", label: "Members" },
              { value: "340", label: "Online", href: "/online" },
            ],
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-stats__item")
      .exists({ count: 2 }, "renders a stat per item");
    assert
      .dom(".d-block-stats__item:first-child .d-block-stats__value")
      .hasText("1.2k");
    assert
      .dom("a.d-block-stats__item")
      .exists({ count: 1 }, "only the item with an href is a link");
  });

  test("list renders ordered or unordered based on the arg", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: List,
          args: {
            ordered: true,
            items: [{ content: "First" }, { content: "Second" }],
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("ol.d-block-list--ordered")
      .exists("renders an ordered list when ordered is true");
    assert
      .dom(".d-block-list__item")
      .exists({ count: 2 }, "renders an item per entry");
    assert.dom(".d-block-list__item:first-child").hasText("First");
  });
});
