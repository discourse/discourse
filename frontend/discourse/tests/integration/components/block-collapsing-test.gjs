import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Accordion from "discourse/blocks/builtin/accordion";
import AccordionItem from "discourse/blocks/builtin/accordion-item";
import Carousel from "discourse/blocks/builtin/carousel";
import Heading from "discourse/blocks/builtin/heading";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | collapsing", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, null);
  });

  test("carousel renders a paged track with controls on the live page", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Carousel,
          args: {},
          children: [
            { block: Heading, args: { text: "One" } },
            { block: Heading, args: { text: "Two" } },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-carousel__viewport").exists("renders the paged track");
    assert
      .dom(".d-block-carousel__viewport .d-block-carousel__slide")
      .exists({ count: 2 }, "renders a slide per child");
    assert
      .dom(".d-block-carousel__controls")
      .exists("renders navigation controls for multiple slides");
    assert
      .dom(".d-block-carousel--editing")
      .doesNotExist("not in the expanded editing presentation");
  });

  test("accordion renders collapsible items, open per defaultOpen", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Accordion,
          args: {},
          children: [
            {
              block: AccordionItem,
              args: { title: "First", defaultOpen: true },
              children: [{ block: Heading, args: { text: "Inside first" } }],
            },
            {
              block: AccordionItem,
              args: { title: "Second" },
              children: [{ block: Heading, args: { text: "Inside second" } }],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-accordion").exists("renders the accordion");

    // Each child block is wrapped, so positional CSS selectors can't tell the
    // items apart — index into the matched elements directly instead.
    const items = [...document.querySelectorAll(".d-block-accordion-item")];
    assert.strictEqual(items.length, 2, "renders an item per child");
    assert.true(
      items[0].hasAttribute("open"),
      "the defaultOpen item starts expanded"
    );
    assert.false(
      items[1].hasAttribute("open"),
      "the other item starts collapsed"
    );
    assert
      .dom(items[0].querySelector(".d-block-accordion-item__summary"))
      .hasText("First");
  });
});
