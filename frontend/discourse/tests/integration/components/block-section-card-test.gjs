import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Card from "discourse/blocks/builtin/card";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import Section from "discourse/blocks/builtin/section";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | section card tiles", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("section renders its children over a persistent backdrop marker", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Section,
          args: {},
          children: [{ block: Heading, args: { text: "Hello", level: 2 } }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-section").exists("the section renders");
    assert
      .dom(".d-block-section__backdrop[data-block-arg='background']")
      .exists("the background arg keeps a persistent backdrop marker");
    assert
      .dom(".d-block-section__content .d-block-heading")
      .exists("the overlay content renders the child heading");
    assert
      .dom(".d-block-section .d-block-stretched-link")
      .doesNotExist("no stretched link without an href");
  });

  test("section with an href renders an accessible stretched link", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Section,
          args: { href: "https://example.com", linkLabel: "Read more" },
          children: [{ block: Heading, args: { text: "Hello", level: 2 } }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-section .d-block-stretched-link")
      .hasAttribute("href", "https://example.com")
      .hasAttribute(
        "aria-label",
        "Read more",
        "the stretched link carries an accessible name"
      );
  });

  test("card renders an empty image marker and a whole-card link", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Card,
          args: { title: "A card", href: "https://example.com" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-card").exists("the card renders");
    assert
      .dom(".d-block-card__image--empty[data-block-arg='image']")
      .exists("the image arg keeps a persistent empty marker");
    assert.dom(".d-block-card__title").exists("the title wrapper renders");
    assert
      .dom(".d-block-card .d-block-stretched-link")
      .hasAttribute("href", "https://example.com");
  });

  test("card renders a leading icon and an external new-tab link", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Card,
          args: {
            title: "A card",
            icon: "star",
            href: "https://example.com",
            external: true,
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-card__icon[data-block-arg='icon'] .d-icon-star")
      .exists("the leading icon renders from the icon arg");
    assert
      .dom(".d-block-card .d-block-stretched-link")
      .hasAttribute("target", "_blank", "the external link opens in a new tab")
      .hasAttribute("rel", "noopener");
  });

  test("card omits the icon marker when no icon is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: Card, args: { title: "A card" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-card__icon")
      .doesNotExist("no icon marker without an icon arg");
    assert
      .dom(".d-block-card .d-block-stretched-link")
      .doesNotExist("no stretched link without an href");
  });

  test("layout Tiles mode renders a placement-free auto-fit grid", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Layout,
          args: { mode: "tiles", minItemWidth: "20rem" },
          children: [
            { block: Card, args: { title: "One" } },
            { block: Card, args: { title: "Two" } },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-layout--tiles")
      .exists("the layout renders in tiles mode");
    assert
      .dom(".d-block-layout--tiles .d-block-card")
      .exists({ count: 2 }, "both card children render as tiles");

    const tiles = document.querySelector(".d-block-layout--tiles");
    assert.true(
      tiles
        .getAttribute("style")
        .includes("--d-block-layout-min-item-width: 20rem"),
      "the min item width is emitted for the auto-fit grid"
    );
    assert
      .dom(".d-block-layout--tiles .d-block-layout__cell")
      .doesNotExist(
        "tiles mode wraps no per-child grid cells (placement-free)"
      );
  });
});
