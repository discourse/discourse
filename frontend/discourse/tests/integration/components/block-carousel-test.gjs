import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Carousel from "discourse/blocks/builtin/carousel";
import Heading from "discourse/blocks/builtin/heading";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// A carousel slide is an arbitrary child block; a heading is enough to assert
// the slide rendered and which slide is which.
function slide(text) {
  return { block: Heading, args: { text } };
}

function renderCarousel(api) {
  api.renderBlocks("hero-blocks", [
    {
      block: Carousel,
      args: {},
      children: [slide("One"), slide("Two"), slide("Three")],
    },
  ]);
}

module("Integration | Blocks | carousel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, null);
  });

  test("renders a paged viewport with nav controls on the live page", async function (assert) {
    withPluginApi(renderCarousel);

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-carousel__viewport")
      .exists("renders the scroll-snap viewport");
    assert
      .dom(".d-block-carousel__viewport .d-block-carousel__slide")
      .exists({ count: 3 }, "every slide renders in the track");
    assert
      .dom(".d-block-carousel__nav--prev")
      .exists("renders the prev control");
    assert
      .dom(".d-block-carousel__nav--next")
      .exists("renders the next control");
    assert
      .dom(".d-block-carousel__dot")
      .exists({ count: 3 }, "renders a dot per slide");
    assert
      .dom("[data-wf-carousel-nav]")
      .doesNotExist("the nav marker is editor-only");
    assert
      .dom(".d-block-carousel__viewport")
      .doesNotHaveAttribute(
        "data-wf-drop-container",
        "the drop hooks are editor-only"
      );
  });

  test("hides the controls for a single slide", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: Carousel, args: {}, children: [slide("Only")] },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-carousel__controls")
      .doesNotExist("a single-slide carousel has nothing to page");
  });

  test("renders the same paged viewport (not stacked) under edit presentation", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

    withPluginApi(renderCarousel);

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // Parity: the editing context reuses the live viewport, it does not stack.
    assert
      .dom(".d-block-carousel--editing")
      .doesNotExist("slides are not stacked under edit presentation");
    assert
      .dom(".d-block-carousel__viewport")
      .exists("the paged viewport renders under edit presentation");
    assert
      .dom(".d-block-carousel__viewport .d-block-carousel__slide")
      .exists({ count: 3 }, "every slide is in the track for editing");

    // Each control carries the marker that lets editing tooling page the track.
    assert
      .dom("[data-wf-carousel-nav]")
      .exists({ count: 5 }, "prev, next, and each dot carry the nav marker");

    // The viewport carries the drop hooks so editing tooling projects drops
    // onto the slides horizontally and names positions in slide terms.
    assert
      .dom(".d-block-carousel__viewport")
      .hasAttribute("data-wf-drop-container", "true")
      .hasAttribute("data-wf-drop-axis", "x")
      .hasAttribute("data-wf-child-noun", "slide")
      .hasAttribute("data-wf-child-noun-plural", "slides");
  });

  test("paging updates the active dot under edit presentation", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

    withPluginApi(renderCarousel);

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const dots = () => [...document.querySelectorAll(".d-block-carousel__dot")];
    assert
      .dom(dots()[0])
      .hasClass("is-active", "the first slide starts active");

    await click(".d-block-carousel__nav--next");
    assert
      .dom(dots()[1])
      .hasClass("is-active", "next pages forward to the second slide");

    await click(dots()[2]);
    assert
      .dom(dots()[2])
      .hasClass("is-active", "clicking a dot pages to that slide");
  });
});
