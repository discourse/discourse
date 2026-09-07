import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockImage from "discourse/blocks/block-image";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Card from "discourse/blocks/builtin/card";
import Heading from "discourse/blocks/builtin/heading";
import Image from "discourse/blocks/builtin/image";
import Layout from "discourse/blocks/builtin/layout";
import Section from "discourse/blocks/builtin/section";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | section and card", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, null);
    _resetOutletLayoutsForTesting();
  });

  test("shared image composition applies fit, position, and zoom to section backgrounds", async function (assert) {
    const image = {
      url: "/images/featured-light.png",
      width: 1600,
      height: 900,
      fit: "contain",
      position: { x: 20, y: 80 },
      zoom: 175,
    };
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Section,
          args: { backgroundImage: image, minHeight: "medium" },
          children: [{ block: Heading, args: { text: "Community" } }],
        },
      ])
    );
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    const section = find(".d-block-section");
    const background = section.querySelector("img");
    assert.strictEqual(getComputedStyle(background).objectFit, "contain");
    assert.strictEqual(getComputedStyle(background).objectPosition, "20% 80%");
    assert.strictEqual(
      getComputedStyle(background).transform,
      "matrix(1.75, 0, 0, 1.75, 0, 0)"
    );
    assert.closeTo(
      section
        .querySelector("[data-block-arg='backgroundImage']")
        .getBoundingClientRect().height,
      section.getBoundingClientRect().height,
      1
    );
  });

  test("shared image frame separates source dimensions and preserves alt text and caption", async function (assert) {
    const image = {
      url: "/images/featured-light.png",
      width: 1600,
      height: 900,
      frame: { width: 320, height: 240 },
      position: { x: 0, y: 100 },
      zoom: 150,
    };
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Image,
          args: {
            image,
            alt: "Community building",
            caption: "Our community",
            link: "/about",
          },
        },
      ])
    );
    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    assert.dom("img").hasAttribute("alt", "Community building");
    assert.dom("figcaption").hasText("Our community");
    const frame = find("[data-block-arg='image']");
    assert.strictEqual(frame.offsetWidth, 320, "uses the authored frame width");
    assert.strictEqual(
      frame.offsetHeight,
      240,
      "uses the authored frame height"
    );
    assert.strictEqual(
      getComputedStyle(frame.querySelector("img")).objectPosition,
      "0% 100%"
    );
    assert.dom("[data-block-arg='image'] figcaption").doesNotExist();
    assert.strictEqual(
      image.width,
      1600,
      "rendering preserves source resolution"
    );
  });

  test("shared image uses a grid-owned frame without erasing authored dimensions", async function (assert) {
    const image = {
      url: "/images/featured-light.png",
      width: 1600,
      height: 900,
      frame: { width: 120, height: 80 },
      zoom: 150,
    };
    await render(
      <template>
        <div class="d-block-layout__cell" style="width: 400px; height: 300px;">
          <BlockImage @image={{image}} />
        </div>
      </template>
    );
    assert.strictEqual(
      find(".d-block-image-frame").offsetWidth,
      400,
      "the grid owns frame width"
    );
    assert.strictEqual(
      find(".d-block-image-frame").offsetHeight,
      300,
      "the grid owns frame height"
    );
    assert.deepEqual(
      image.frame,
      { width: 120, height: 80 },
      "the explicit frame is retained for use outside a grid"
    );
  });

  test("section renders a semantic surface with a persistent background marker", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Section,
          args: {
            accessibleLabel: "Featured discussions",
            backgroundImage: {
              url: "/images/featured-light.png",
              width: 1600,
              height: 900,
              position: { x: 100, y: 0 },
              dark: {
                url: "/images/featured-dark.png",
                width: 1600,
                height: 900,
              },
            },
            contentWidth: "wide",
            minHeight: "medium",
            padding: "large",
            scrim: "strong",
            surface: "subtle",
            verticalAlign: "center",
          },
          children: [{ block: Heading, args: { text: "Hello", level: 2 } }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-section")
      .hasAttribute("aria-label", "Featured discussions")
      .hasClass("--surface-subtle")
      .hasClass("--scrim-strong")
      .hasClass("--padding-large")
      .hasClass("--width-wide")
      .hasClass("--height-medium")
      .hasClass("--align-center");
    assert
      .dom(
        ".d-block-section__backdrop[data-block-arg='backgroundImage'][data-drop-passive]"
      )
      .exists("the image arg keeps a persistent backdrop marker")
      .doesNotHaveAttribute(
        "data-drop-fills-block",
        "consumers measure the backdrop instead of the outer wrapper"
      );
    assert
      .dom(".d-block-section__backdrop img")
      .hasAttribute("src", /featured-light\.png/)
      .hasAttribute("alt", "");

    const sectionRect = find(".d-block-section").getBoundingClientRect();
    const backdropRect = find(
      ".d-block-section__backdrop"
    ).getBoundingClientRect();

    assert.closeTo(
      backdropRect.width,
      sectionRect.width,
      1,
      "the backdrop spans the section width"
    );
    assert.closeTo(
      backdropRect.height,
      sectionRect.height,
      1,
      "the backdrop spans the section height"
    );
    assert.dom(".d-block-section__scrim").exists("the selected scrim renders");
    assert
      .dom(".d-block-section__content .d-block-heading")
      .exists("the section content renders the child heading");
  });

  test("section exposes its stable content host only to editing tools", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

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

    assert
      .dom(".d-block-section__content")
      .hasAttribute("data-wf-drop-container", "true")
      .hasAttribute(
        "data-wf-empty-host",
        "true",
        "consumers can mount an empty affordance inside the content area"
      );
  });

  test("section does not shrink a nested layout", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Section,
          args: {},
          children: [
            {
              block: Layout,
              args: { mode: "grid", columns: 2 },
              children: [
                { block: Heading, args: { text: "One", level: 2 } },
                { block: Heading, args: { text: "Two", level: 2 } },
              ],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    const contentWidth = find(
      ".d-block-section__content"
    ).getBoundingClientRect().width;
    const layoutWidth = find(
      ".d-block-section__content .d-block-layout"
    ).getBoundingClientRect().width;

    assert.closeTo(
      layoutWidth,
      contentWidth,
      1,
      "the nested layout spans the section content boundary"
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
});
