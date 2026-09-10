import { trustHTML } from "@ember/template";
import {
  clearRender,
  find,
  findAll,
  render,
  rerender,
  settled,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
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
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

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

  test("card exposes an empty image marker in editing and an opted-in whole-card link", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Card,
          args: {
            title: "A card",
            href: "https://example.com",
            wholeCard: true,
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-card").exists("the card renders");
    assert
      .dom(".d-block-card__image[data-block-arg='image']")
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
            wholeCard: true,
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
      .hasAttribute("rel", "noopener noreferrer");
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

async function setLeafCard(args = {}) {
  let pending;
  withPluginApi((api) => {
    pending = api.setLayoutLayer(
      "hero-blocks",
      "session-draft",
      [{ block: Card, args }],
      { permissive: true }
    );
  });
  await pending;
}

async function renderLeafCard(args = {}) {
  await setLeafCard(args);
  await render(<template><BlockOutlet @name="hero-blocks" /></template>);
}

module("Integration | Component | leaf Card", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, null);
    _resetOutletLayoutsForTesting();
  });

  test("declares one leaf with the new presentation contract", function (assert) {
    const metadata = getBlockMetadata(Card);
    assert.strictEqual(
      metadata.container,
      undefined,
      "Card cannot contain child blocks"
    );
    assert.deepEqual(
      metadata.args.presentation?.enum,
      ["none", "above", "below", "beside", "behind"],
      "one Card supplies all presentations"
    );
    assert.false(
      metadata.args.wholeCard?.default,
      "whole-card navigation is opt-in"
    );
    assert.strictEqual(
      metadata.args.variant,
      undefined,
      "the pre-release variant API is removed"
    );
    assert.strictEqual(
      metadata.args.backgroundColor,
      undefined,
      "surfaces replace raw colors"
    );
  });

  test("empty reader cards reserve no optional regions", async function (assert) {
    await renderLeafCard();
    assert.dom(".d-block-card").exists("the card remains a leaf surface");
    assert.dom(".d-block-card h3").doesNotExist("no empty heading");
    assert.dom(".d-block-card img").doesNotExist("no empty image");
    assert.dom(".d-block-card a").doesNotExist("no empty link");
    assert
      .dom(".d-block-card__content")
      .doesNotExist("no phantom content padding");
    assert.dom(".d-block-card__identity").doesNotExist("no empty identity");
  });

  test("visual regression: title icons share the heading row at narrow widths", async function (assert) {
    await setLeafCard({
      title: "Community newsletter and upcoming events",
      icon: "envelope",
    });
    await render(
      <template>
        <div class="card-test-width" style="width: 220px"><BlockOutlet
            @name="hero-blocks"
          /></div>
      </template>
    );
    const host = find(".card-test-width");

    for (const dir of ["ltr", "rtl"]) {
      host.dir = dir;
      for (const iconStyle of ["plain", "tile"]) {
        await setLeafCard({
          title: "Community newsletter and upcoming events",
          icon: "envelope",
          iconStyle,
        });
        await settled();
        const icon = find(".d-block-card__icon").getBoundingClientRect();
        const title = find(".d-block-card__title").getBoundingClientRect();
        assert.true(
          icon.bottom > title.top,
          `${dir} ${iconStyle}: icon does not occupy a row above the heading`
        );
        assert.true(
          icon.top < title.bottom,
          `${dir} ${iconStyle}: icon does not occupy a row below the heading`
        );
        assert.true(
          dir === "ltr" ? icon.right <= title.left : icon.left >= title.right,
          `${dir} ${iconStyle}: icon leads the heading`
        );
        assert
          .dom(".d-block-card__title")
          .hasText(
            "Community newsletter and upcoming events",
            "the decorative icon does not change the heading text"
          );
      }
    }
  });

  test("visual regression: media badges hug short copy and contain long copy", async function (assert) {
    const args = {
      presentation: "behind",
      image: { url: "/images/avatar.png" },
      title: "Champion",
      eyebrow: "Featured",
      labelStyle: "badge",
      labelPlacement: "media",
    };
    await setLeafCard(args);
    await render(
      <template>
        <div class="card-test-width" style="width: 480px"><BlockOutlet
            @name="hero-blocks"
          /></div>
      </template>
    );
    const host = find(".card-test-width");
    await settled();
    const media = find(".d-block-card__media").getBoundingClientRect();
    assert.true(
      find(".d-block-card__label").getBoundingClientRect().width <
        media.width / 2,
      "a short badge does not stretch across the image"
    );

    host.style.width = "220px";
    await setLeafCard({
      ...args,
      eyebrow:
        "An exceptionally long championship announcement with more details",
    });
    await settled();
    const label = find(".d-block-card__label");
    const bounds = find(".d-block-card").getBoundingClientRect();
    const badge = label.getBoundingClientRect();
    assert.true(
      badge.left >= bounds.left,
      "the long badge's left edge remains within the narrow card"
    );
    assert.true(
      badge.right <= bounds.right,
      "the long badge's right edge remains within the narrow card"
    );
    assert.true(
      label.scrollWidth <= label.clientWidth + 1,
      "the long badge wraps instead of clipping"
    );

    for (const dir of ["ltr", "rtl"]) {
      host.dir = dir;
      host.style.fontSize = "200%";
      await settled();
      const currentBadge = find(".d-block-card__label");
      const title = find(".d-block-card__title").getBoundingClientRect();
      const card = find(".d-block-card").getBoundingClientRect();
      const image = find(".d-block-card__image").getBoundingClientRect();
      assert
        .dom(currentBadge)
        .hasText(
          "An exceptionally long championship announcement with more details",
          `${dir}: retains all badge content at double text size`
        );
      assert.true(
        currentBadge.getBoundingClientRect().bottom < title.top,
        `${dir}: a wrapped media badge has its own space above the copy`
      );
      assert.closeTo(
        image.height,
        card.height - 1,
        1,
        `${dir}: the image still covers both regions`
      );
    }
  });

  test("shared composition and explicit alternative text survive presentation changes", async function (assert) {
    const image = {
      source: "upload",
      upload_id: 41,
      url: "/images/avatar.png",
      width: 640,
      height: 480,
      fit: "contain",
      position: { x: 17, y: 82 },
      zoom: 140,
      dark: { source: "upload", upload_id: 42, url: "/images/avatar.png" },
    };
    const original = structuredClone(image);
    const args = {
      image,
      imageAlt: "A prism splitting light",
      imageDecorative: false,
      presentation: "above",
      title: "Exhibition",
    };
    await renderLeafCard(args);
    assert
      .dom("[data-block-arg='image'] .d-block-image-frame")
      .exists("uses shared image rendering");
    assert
      .dom("[data-block-arg='image'] img")
      .hasAttribute("alt", "A prism splitting light", "uses explicit alt");
    const frame = find("[data-block-arg='image'] .d-block-image-frame");
    assert.strictEqual(
      frame?.style.getPropertyValue("--block-image-zoom"),
      "1.4",
      "the saved zoom reaches the shared frame"
    );
    await setLeafCard({ ...args, presentation: "none" });
    await rerender();
    assert.dom(".d-block-card img").doesNotExist("content-only hides media");
    await setLeafCard({ ...args, presentation: "below" });
    await rerender();
    assert.dom(".d-block-card").hasClass("--below", "restores media below");
    assert
      .dom("[data-block-arg='image'] img")
      .hasAttribute("alt", "A prism splitting light", "alt survives hiding");
    assert.deepEqual(
      image,
      original,
      "source, dark upload and crop remain untouched"
    );
  });

  test("below media follows content in DOM order with independent heading semantics", async function (assert) {
    await renderLeafCard({
      headingLevel: 2,
      image: { url: "/images/avatar.png" },
      presentation: "below",
      scale: "compact",
      title: "Collection story",
    });
    assert
      .dom("h2.d-block-card__title")
      .hasText("Collection story", "heading level is independent of scale");
    const content = find(".d-block-card__content");
    const media = find(".d-block-card__media");
    assert.strictEqual(
      content?.compareDocumentPosition(media),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "Below uses meaningful DOM order"
    );
  });

  test("visible primary and secondary actions keep independent names and destinations", async function (assert) {
    await renderLeafCard({
      actionLabel: "Watch now",
      external: true,
      href: "/watch",
      linkLabel: "A different invisible name",
      secondaryEnabled: true,
      secondaryHref: "/transcript",
      secondaryLabel: "Read transcript",
      title: "A different title",
      wholeCard: true,
    });
    assert
      .dom(".d-block-card__primary")
      .hasText("Watch now", "visible primary label survives");
    assert
      .dom(".d-block-card__primary")
      .doesNotHaveAttribute(
        "aria-label",
        "the title or override does not replace its name"
      );
    assert
      .dom(".d-block-card__primary")
      .hasAttribute("href", "/watch", "primary destination");
    assert
      .dom(".d-block-card__primary")
      .hasAttribute("target", "_blank", "primary external intent");
    assert
      .dom(".d-block-card__secondary")
      .hasAttribute("href", "/transcript", "independent secondary destination");
    assert
      .dom(".d-block-card__secondary")
      .doesNotHaveAttribute("target", "secondary stays in the same tab");
    assert
      .dom(".d-block-card .d-block-stretched-link")
      .exists({ count: 1 }, "one stretched anchor");
    assert.strictEqual(
      findAll(".d-block-card a").length,
      2,
      "no duplicate primary tab stop"
    );
    assert.dom(".d-block-card a a").doesNotExist("no nested anchors");
  });

  test("whole-card-only link extracts its name from rich title and is opt-in", async function (assert) {
    const title = {
      type: "doc",
      content: [
        { type: "text", text: "Beyond", marks: [{ type: "strong" }] },
        { type: "hard_break" },
        { type: "text", text: "the visible" },
      ],
    };
    await renderLeafCard({ title });
    assert.dom(".d-block-card a").doesNotExist("unlinked by default");
    await setLeafCard({ href: "/exhibition", title, wholeCard: true });
    await rerender();
    assert
      .dom(".d-block-stretched-link")
      .hasAttribute(
        "aria-label",
        "Beyond the visible",
        "extracts text instead of stringifying the document"
      );
  });

  test("media identity is unboxed and returns to content when feature media is hidden", async function (assert) {
    const image = { url: "/images/avatar.png" };
    const args = {
      avatar: image,
      identityEnabled: true,
      identityFormat: "feature",
      identityName: "Sam Saffron",
      identityPlacement: "media",
      identityRole: "Co-founder, Discourse",
      identityTreatment: "theme",
      image,
      presentation: "above",
      title: "A decade of Discourse",
    };
    await renderLeafCard(args);
    assert
      .dom(".d-block-card__media .d-block-card__identity")
      .exists("identity belongs to media");
    assert
      .dom("[data-block-arg='avatar'] img")
      .hasAttribute("alt", "", "the adjacent name supplies identity");
    assert
      .dom(".d-block-card__identity")
      .hasText(
        "Sam Saffron Co-founder, Discourse",
        "name and role render once"
      );
    await setLeafCard({ ...args, presentation: "none" });
    await rerender();
    assert
      .dom(".d-block-card__content .d-block-card__identity")
      .exists("hidden feature media moves identity into content");
    assert
      .dom(".d-block-card__identity")
      .exists({ count: 1 }, "no duplicated identity");
  });

  test("visual regression: media treatments preserve text contrast across palettes", async function (assert) {
    const args = {
      image: { url: "/images/avatar.png" },
      identityEnabled: true,
      identityName: "Sam Saffron",
      identityPlacement: "media",
      identityTreatment: "theme",
      presentation: "above",
      title: "A decade of Discourse",
    };
    await renderLeafCard(args);
    const media = find(".d-block-card__media");
    const tint = getComputedStyle(media, "::after");
    assert.notStrictEqual(
      tint.content,
      "none",
      "the tint covers the image, not just its backing surface"
    );
    assert.notStrictEqual(
      tint.backgroundColor,
      "rgba(0, 0, 0, 0)",
      "the image has a visible theme tint"
    );

    const palette = document.documentElement;
    const originalPalette = palette.getAttribute("style");
    try {
      for (const presentation of ["above", "behind"]) {
        await setLeafCard({
          ...args,
          presentation,
          identityTreatment: "photo",
        });
        await rerender();
        for (const scheme of ["light", "dark"]) {
          palette.style.colorScheme = scheme;
          palette.style.setProperty(
            "--primary",
            scheme === "light" ? "#222" : "#eee"
          );
          palette.style.setProperty(
            "--primary-rgb",
            scheme === "light" ? "34, 34, 34" : "238, 238, 238"
          );
          palette.style.setProperty(
            "--secondary",
            scheme === "light" ? "#fff" : "#222"
          );
          const text = find(
            presentation === "above"
              ? ".d-block-card__identity-name"
              : ".d-block-card__title"
          );
          assert.strictEqual(
            getComputedStyle(text).color,
            scheme === "light" ? "rgb(255, 255, 255)" : "rgb(238, 238, 238)",
            `${presentation}: ${scheme} keeps light text over photography`
          );
          const overlay = getComputedStyle(
            find(".d-block-card__media"),
            "::after"
          );
          const darkensImage =
            overlay.backgroundColor.startsWith("rgba(0, 0, 0,") ||
            overlay.backgroundImage.includes("rgba(0, 0, 0,");
          assert.true(
            darkensImage,
            `${presentation}: ${scheme} darkens photography instead of whitening it`
          );
        }
      }
    } finally {
      if (originalPalette === null) {
        palette.removeAttribute("style");
      } else {
        palette.setAttribute("style", originalPalette);
      }
    }
  });

  test("visual regression: inline actions fit beside long copy without clipping", async function (assert) {
    await setLeafCard({
      presentation: "none",
      title:
        "Secure by Design: Our free guide to building privacy-focused communities",
      body: "Discover how Discourse is designed to safeguard your data and support communities.",
      actionLabel: "Download your copy",
      href: "/guide",
      actionStyle: "button",
      actionLayout: "inline",
    });
    await render(
      <template>
        <div class="card-test-width" style="width: 888px"><BlockOutlet
            @name="hero-blocks"
          /></div>
      </template>
    );
    const host = find(".card-test-width");
    for (const dir of ["ltr", "rtl"]) {
      host.dir = dir;
      host.style.width = "888px";
      await settled();
      const wideAction = find(".d-block-card__primary").getBoundingClientRect();
      const wideCopy = find(".d-block-card__copy").getBoundingClientRect();
      assert.true(
        wideAction.top < wideCopy.bottom,
        `${dir}: wide actions start beside copy`
      );
      assert.true(
        wideAction.bottom > wideCopy.top,
        `${dir}: wide actions end beside copy`
      );
      for (const width of [888, 520, 320, 220]) {
        host.style.width = `${width}px`;
        await settled();
        const card = find(".d-block-card");
        const content = find(".d-block-card__content");
        const action = find(".d-block-card__primary").getBoundingClientRect();
        const bounds = card.getBoundingClientRect();
        assert.true(
          content.scrollWidth <= content.clientWidth + 1,
          `${dir} ${width}: copy and actions fit inside the card`
        );
        assert.true(
          action.left >= bounds.left,
          `${dir} ${width}: the action's left edge is visible`
        );
        assert.true(
          action.right <= bounds.right,
          `${dir} ${width}: the action's right edge is visible`
        );
      }
    }
  });

  test("review regression: narrow Card buttons retain complete long labels", async function (assert) {
    await setLeafCard({
      title: "Community research",
      actionLabel: "Download the complete community research report",
      href: "/report",
      secondaryEnabled: true,
      secondaryLabel:
        "Read the supplementary research and interview transcripts " +
        "UnbrokenLabel".repeat(5),
      secondaryHref: "/transcripts",
      actionStyle: "button",
    });
    await render(
      <template>
        <div class="card-test-width" style="width: 220px"><BlockOutlet
            @name="hero-blocks"
          /></div>
      </template>
    );
    for (const [direction, fontSize] of [
      ["ltr", "1em"],
      ["rtl", "1em"],
      ["ltr", "2em"],
      ["rtl", "2em"],
    ]) {
      find(".card-test-width").dir = direction;
      find(".card-test-width").style.fontSize = fontSize;
      await settled();
      const content = find(".d-block-card__content");
      const bounds = content.getBoundingClientRect();
      for (const action of findAll(".d-block-card__actions .btn")) {
        const box = action.getBoundingClientRect();
        const text = document.createRange();
        text.selectNodeContents(action);
        const words = [...text.getClientRects()];
        assert.true(
          box.left >= bounds.left,
          `${direction} ${fontSize}: the action's left edge fits in the Card`
        );
        assert.true(
          box.right <= bounds.right,
          `${direction} ${fontSize}: the action's right edge fits in the Card`
        );
        assert.true(
          words.every(
            (word) =>
              word.left >= box.left &&
              word.right <= box.right &&
              word.top >= box.top &&
              word.bottom <= box.bottom
          ),
          `${direction} ${fontSize}: all action text stays inside its button`
        );
        assert.true(
          action.scrollWidth <= action.clientWidth + 1,
          `${direction} ${fontSize}: no action text is hidden by overflow`
        );
      }
    }
  });

  test("editing exposes independent empty image and portrait targets", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);
    await renderLeafCard({ identityEnabled: true, identityName: "Speaker" });
    assert
      .dom("[data-block-arg='image']")
      .exists({ count: 1 }, "feature image can be uploaded");
    assert
      .dom("[data-block-arg='avatar']")
      .exists({ count: 1 }, "portrait has its own upload target");
    assert.dom(".d-block-card__title").exists("empty title is editable");
  });

  test("cross-field validation accepts empty drafts and diagnoses incomplete active features", function (assert) {
    const validateFn = getBlockMetadata(Card).validate;
    assert.strictEqual(
      typeof validateFn,
      "function",
      "Card supplies cross-field validation"
    );
    const validate = (args) => validateFn(args).map(({ message }) => message);
    assert.deepEqual(validate({}), [], "empty leaf is an editable draft");
    assert.deepEqual(
      validate({ identityEnabled: true }),
      [],
      "empty enabled identity stays editable"
    );
    assert.deepEqual(validate({ href: "/watch" }), [
      i18n("blocks.builtin.card.errors.primary_label"),
    ]);
    assert.deepEqual(validate({ actionLabel: "Watch now" }), [
      i18n("blocks.builtin.card.errors.primary_href"),
    ]);
    assert.deepEqual(validate({ href: "/watch", wholeCard: true }), [
      i18n("blocks.builtin.card.errors.link_name"),
    ]);
    assert.deepEqual(
      validate({ title: "Talk", href: "/watch", wholeCard: true }),
      []
    );
    assert.deepEqual(
      validate({ href: "/watch", actionLabel: "Watch now", wholeCard: true }),
      []
    );
    assert.deepEqual(
      validate({
        secondaryEnabled: true,
        secondaryHref: "/transcript",
        secondaryLabel: "Transcript",
      }),
      [],
      "secondary-only is valid"
    );
    assert.deepEqual(validate({ secondaryEnabled: true }), [
      i18n("blocks.builtin.card.errors.secondary"),
      i18n("blocks.builtin.card.errors.secondary"),
    ]);
    assert.deepEqual(
      validate({ identityEnabled: true, avatar: { url: "/avatar.png" } }),
      [i18n("blocks.builtin.card.errors.identity_name")]
    );
    assert.deepEqual(
      validate({ identityEnabled: false, avatar: { url: "/avatar.png" } }),
      [],
      "inactive identity does not require copy"
    );
    assert.deepEqual(
      validate({ image: { url: "/prism.png" }, imageDecorative: false }),
      [i18n("blocks.builtin.card.errors.image_alt")]
    );
    assert.deepEqual(
      validate({
        image: { url: "/prism.png" },
        imageDecorative: false,
        presentation: "none",
      }),
      [],
      "hidden media preserves inactive alt intent"
    );
  });

  test("whole-card opt-in and whitespace documents never produce unnamed or duplicate links", async function (assert) {
    const title = {
      type: "doc",
      content: [
        { type: "text", text: "  ", marks: [{ type: "em" }] },
        { type: "hard_break" },
      ],
    };
    await renderLeafCard({ title, href: "/watch", wholeCard: true });
    assert.dom(".d-block-card a").doesNotExist("no unnamed stretched link");
    assert
      .dom(".d-block-card__title")
      .doesNotExist("whitespace is not a heading");
    await setLeafCard({ title: "Talk", href: "/watch", wholeCard: false });
    await rerender();
    assert
      .dom(".d-block-card a")
      .doesNotExist("a destination alone does not opt in");
    await setLeafCard({
      title: "Talk",
      href: "/watch",
      wholeCard: true,
      linkLabel: "Play talk",
    });
    await rerender();
    assert
      .dom(".d-block-stretched-link")
      .hasAttribute("aria-label", "Play talk");
  });

  test("label and identity toggles preserve their independent stored values", async function (assert) {
    const args = {
      image: { url: "/images/avatar.png" },
      presentation: "behind",
      eyebrow: "Podcast",
      labelStyle: "badge",
      labelPlacement: "media",
      icon: "headphones",
      iconTarget: "label",
      identityEnabled: true,
      identityName: "Sam Saffron",
      identityRole: "Co-founder",
      avatarDisplay: "initials",
      identityPlacement: "media",
      identityFormat: "stacked",
      title: "A decade",
    };
    await renderLeafCard(args);
    assert
      .dom(".d-block-card__media .d-block-card__label.--badge")
      .hasText("Podcast");
    assert
      .dom(".d-block-card__content .d-block-card__identity")
      .exists("Behind identity falls back to content");
    assert
      .dom(".d-block-card__avatar")
      .hasText("SS")
      .hasAttribute("aria-hidden", "true");
    await setLeafCard({
      ...args,
      presentation: "none",
      identityEnabled: false,
    });
    await rerender();
    assert
      .dom(".d-block-card__content .d-block-card__label")
      .hasText("Podcast");
    assert
      .dom(".d-block-card__identity")
      .doesNotExist("disabled identity leaves no shell");
    await setLeafCard({ ...args, presentation: "above" });
    await rerender();
    assert
      .dom(".d-block-card__media .d-block-card__identity")
      .exists("saved placement returns when eligible");
    assert.dom(".d-block-card__identity-role").hasText("Co-founder");
    assert.dom(".d-block-card__avatar").hasText("SS");
  });

  test("beside adapts to its allocation with distinct adaptive and even splits and meaningful DOM order", async function (assert) {
    const args = {
      image: { url: "/images/avatar.png" },
      title: "A promotional card",
      body: "Enough copy to demonstrate the relationship between media and content.",
      presentation: "beside",
      imageSide: "end",
    };
    await setLeafCard(args);
    await render(
      <template>
        <div class="card-test-width" style="width: 800px"><BlockOutlet
            @name="hero-blocks"
          /></div>
      </template>
    );

    let media = find(".d-block-card__media");
    let content = find(".d-block-card__content");
    assert.true(
      media.getBoundingClientRect().width <
        content.getBoundingClientRect().width,
      "adaptive media leaves more room for copy"
    );
    assert.strictEqual(
      content.compareDocumentPosition(media),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "end media follows content in DOM order"
    );
    await setLeafCard({ ...args, imageWidth: "even" });
    await rerender();
    media = find(".d-block-card__media");
    content = find(".d-block-card__content");
    assert.closeTo(
      media.getBoundingClientRect().width,
      content.getBoundingClientRect().width,
      1,
      "even split is genuinely 50/50"
    );
    find(".card-test-width").style.width = "220px";
    window.dispatchEvent(new Event("resize"));
    await waitUntil(() => find(".d-block-card").classList.contains("--above"));
    const card = find(".d-block-card");
    assert
      .dom(card)
      .hasClass(
        "--above",
        "narrow allocation resolves to Above even on a wide viewport"
      );
    media = find(".d-block-card__media");
    content = find(".d-block-card__content");
    assert.strictEqual(
      media.compareDocumentPosition(content),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "fallback also changes the DOM order"
    );
    assert.true(
      content.getBoundingClientRect().top >=
        media.getBoundingClientRect().bottom - 1,
      "no cramped side-by-side copy"
    );
    assert.true(
      card.scrollWidth <= card.clientWidth + 1,
      "no horizontal overflow"
    );
  });

  test("image media remains bounded in a wide Stack while long content can grow", async function (assert) {
    const image = { url: "/images/avatar.png" };
    await setLeafCard({
      image,
      presentation: "above",
      title: "A wide story",
      body: "Long copy. ".repeat(180),
    });
    await render(
      <template>
        <div style="width: 800px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    const media = find(".d-block-card__media").getBoundingClientRect();
    const content = find(".d-block-card__content").getBoundingClientRect();
    const rem = parseFloat(getComputedStyle(document.documentElement).fontSize);
    assert.true(
      find(".d-block-card__media").offsetHeight <= 18 * rem + 1,
      "media preference does not grow into a giant image"
    );
    assert.true(media.height > 0, "media remains visible");
    assert.true(
      content.height > media.height,
      "long text grows without a total Card height cap"
    );
    assert.closeTo(
      find(".d-block-card__content").scrollHeight,
      find(".d-block-card__content").clientHeight,
      1,
      "content is not clipped"
    );
  });
});

async function setCardLayout(args, children) {
  let pending;
  withPluginApi((api) => {
    pending = api.setLayoutLayer(
      "hero-blocks",
      "session-draft",
      [
        {
          block: Section,
          args: { surface: "subtle" },
          children: [{ block: Layout, args, children }],
        },
      ],
      { permissive: true }
    );
  });
  await pending;
}

async function settleCardLayout() {
  await settled();
  await new Promise(requestAnimationFrame);
  await new Promise(requestAnimationFrame);
  await settled();
}

function storyCard(id, args = {}, grid = {}) {
  return {
    block: Card,
    id,
    args: {
      image: { url: "/images/avatar.png" },
      presentation: "above",
      title: "A story",
      href: "/story",
      actionLabel: "Read more",
      ...args,
    },
    containerArgs: { grid },
  };
}

function cardRegion(id, region) {
  return find(`[data-block-id="${id}"] .d-block-card__${region}`);
}

module("Integration | Blocks | Card layout", function (hooks) {
  setupRenderingTest(hooks);
  hooks.afterEach(() => _resetOutletLayoutsForTesting());

  test("Below peers grow for media identity and release nested, overlapping and non-stretch cards", async function (assert) {
    const args = { mode: "grid", columns: 4, rows: 1, autoCollapse: "never" };
    const one = storyCard(
      "one",
      { presentation: "below", scale: "compact" },
      { column: "1", row: "1" }
    );
    const two = storyCard(
      "two",
      {
        presentation: "below",
        identityEnabled: true,
        identityName: "An exceptionally long speaker name",
        identityRole: "An exceptionally long role. ".repeat(15),
        identityPlacement: "media",
        avatarDisplay: "initials",
        identityFormat: "stacked",
        scale: "featured",
      },
      { column: "2", row: "1" }
    );
    const nested = {
      block: Section,
      containerArgs: { grid: { column: "3", row: "1" } },
      children: [storyCard("nested", { body: "Nested copy. ".repeat(30) })],
    };
    const unstretched = storyCard(
      "unstretched",
      { presentation: "below" },
      { column: "4", row: "1", align: "start" }
    );
    await setCardLayout(args, [one, two, nested, unstretched]);
    await render(
      <template>
        <div style="width: 1080px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    assert.closeTo(
      cardRegion("one", "media").getBoundingClientRect().top,
      cardRegion("two", "media").getBoundingClientRect().top,
      1,
      "Below media starts at a shared seam"
    );
    assert.closeTo(
      cardRegion("one", "actions").getBoundingClientRect().bottom,
      cardRegion("two", "actions").getBoundingClientRect().bottom,
      1,
      "Below action edges align across padding scales"
    );
    assert.true(
      cardRegion("two", "media").clientHeight >=
        cardRegion("two", "identity").offsetHeight,
      "long media identity is not clipped by the preferred image cap"
    );
    assert
      .dom("[data-block-id='nested'] .d-block-card")
      .doesNotHaveAttribute(
        "data-card-aligned",
        "nested authored Card does not join its ancestor's row"
      );
    assert
      .dom("[data-block-id='unstretched'] .d-block-card")
      .doesNotHaveAttribute(
        "data-card-aligned",
        "non-stretch child remains natural"
      );
    const overlapping = {
      ...two,
      containerArgs: { grid: { column: "1", row: "1" } },
    };
    await setCardLayout(args, [one, overlapping, nested, unstretched]);
    await settleCardLayout();
    assert
      .dom("[data-card-aligned]")
      .doesNotExist("overlapping peers are excluded");
  });

  test("one Layout observer releases all allocations and Card regions on teardown", async function (assert) {
    const OriginalObserver = window.ResizeObserver;
    const OriginalMutationObserver = window.MutationObserver;
    const sandbox = sinon.createSandbox();
    const addedFonts = sandbox.spy(document.fonts, "addEventListener");
    const removedFonts = sandbox.spy(document.fonts, "removeEventListener");
    const addedLoads = sandbox.spy(document, "addEventListener");
    const removedLoads = sandbox.spy(document, "removeEventListener");
    const observed = new Map();
    const mutated = new Map();
    class RecordingMutationObserver extends OriginalMutationObserver {
      constructor(callback) {
        super(callback);
        mutated.set(this, new Set());
      }

      observe(target, options) {
        mutated.get(this).add(target);
        super.observe(target, options);
      }

      disconnect() {
        mutated.get(this).clear();
        super.disconnect();
      }
    }
    class RecordingObserver extends OriginalObserver {
      constructor(callback) {
        super(callback);
        observed.set(this, new Set());
      }

      observe(target, options) {
        observed.get(this).add(target);
        super.observe(target, options);
      }

      unobserve(target) {
        observed.get(this).delete(target);
        super.unobserve(target);
      }

      disconnect() {
        observed.get(this).clear();
        super.disconnect();
      }
    }
    window.ResizeObserver = RecordingObserver;
    window.MutationObserver = RecordingMutationObserver;
    try {
      await setCardLayout(
        { mode: "grid", columns: 2, rows: 1, autoCollapse: "never" },
        [storyCard("one"), storyCard("two", { body: "Long copy. ".repeat(12) })]
      );
      await render(
        <template>
          <div style="width: 800px"><BlockOutlet @name="hero-blocks" /></div>
        </template>
      );
      await settleCardLayout();
      const layout = find("[data-block-layout]");
      const owners = [...observed.values()].filter((targets) =>
        targets.has(layout)
      );
      assert.strictEqual(owners.length, 1, "one observer owns the Layout");
      assert.true(
        owners[0].has(cardRegion("one", "copy")),
        "same observer measures the first natural content region"
      );
      assert.true(
        owners[0].has(cardRegion("two", "copy")),
        "same observer measures the other Card"
      );
      const cards = findAll(".d-block-card");
      const mutationOwners = [...mutated.values()].filter((targets) =>
        targets.has(layout)
      );
      assert.strictEqual(
        mutationOwners.length,
        1,
        "one mutation observer owns the Layout"
      );
      assert.true(
        mutationOwners[0].has(document.head),
        "theme changes are observed"
      );
      const fontListeners = addedFonts
        .getCalls()
        .filter(({ args }) => args[0] === "loadingdone");
      const loadListeners = addedLoads
        .getCalls()
        .filter(({ args }) => args[0] === "load" && args[2] === true);
      assert.strictEqual(
        fontListeners.length,
        1,
        "the Layout listens for loaded fonts"
      );
      assert.strictEqual(
        loadListeners.length,
        1,
        "the Layout listens for image and stylesheet loads"
      );
      await clearRender();
      await settleCardLayout();
      assert.strictEqual(
        owners[0].size,
        0,
        "removed Layout releases every observed element"
      );
      assert.strictEqual(
        mutationOwners[0].size,
        0,
        "teardown disconnects mutation observation, including ancestors and head"
      );
      assert.deepEqual(
        [
          fontListeners.every(({ args }) =>
            removedFonts.calledWithExactly(...args)
          ),
          loadListeners.every(({ args }) =>
            removedLoads.calledWithExactly(...args)
          ),
        ],
        [true, true],
        "teardown removes the exact registered font and capture listeners"
      );
      assert.true(
        cards.every(
          (card) =>
            !card.hasAttribute("data-card-aligned") &&
            !card.style.getPropertyValue("--card-aligned-content")
        ),
        "teardown clears transient dimensions from removed Cards"
      );
    } finally {
      window.ResizeObserver = OriginalObserver;
      window.MutationObserver = OriginalMutationObserver;
      sandbox.restore();
    }
  });

  test("Row cards have useful default widths and wrap into independent cohorts", async function (assert) {
    const children = [
      storyCard("one", { body: "Long copy. ".repeat(20), scale: "featured" }),
      storyCard("two", { scale: "compact" }),
      storyCard("three", { body: "A short body" }),
    ];
    this.set("widthStyle", trustHTML("width: 1080px"));
    await setCardLayout({ mode: "row", autoCollapse: "never" }, children);
    await render(
      <template>
        <div style={{this.widthStyle}}><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    assert.true(
      cardRegion("one", "media").offsetWidth > 200,
      "Row gives Card a useful starting allocation"
    );
    assert.closeTo(
      cardRegion("one", "media").getBoundingClientRect().bottom,
      cardRegion("two", "media").getBoundingClientRect().bottom,
      1,
      "first peers share a seam"
    );
    this.set("widthStyle", trustHTML("width: 888px"));
    await settleCardLayout();
    assert.closeTo(
      cardRegion("one", "media").getBoundingClientRect().top,
      cardRegion("three", "media").getBoundingClientRect().top,
      1,
      "three cards still fit at an intermediate allocation"
    );
    assert.closeTo(
      cardRegion("three", "media")
        .closest(".d-block-card")
        .getBoundingClientRect().right,
      find(".d-block-layout__flex").getBoundingClientRect().right,
      1,
      "the cards use the available row instead of leaving an empty gutter"
    );
    this.set("widthStyle", trustHTML("width: 720px"));
    await settleCardLayout();
    assert
      .dom("[data-block-id='one'] .d-block-card")
      .hasAttribute("data-card-aligned", "", "wrapped pair stays coordinated");
    assert
      .dom("[data-block-id='three'] .d-block-card")
      .doesNotHaveAttribute("data-card-aligned", "singleton releases");
    assert.true(
      cardRegion("three", "content").offsetHeight <
        cardRegion("one", "content").offsetHeight,
      "long first row does not inflate singleton"
    );
    this.set("widthStyle", trustHTML("width: 320px"));
    await settleCardLayout();
    assert
      .dom("[data-card-aligned]")
      .doesNotExist("single-column wrapping releases every Card");
    assert.true(
      cardRegion("one", "media").offsetWidth <= 320,
      "default allocation can shrink in a narrow sidebar"
    );
  });

  test("reversed Row peers realign after identity, text size and spacing changes in both directions", async function (assert) {
    const args = { mode: "row", reverse: true, autoCollapse: "never" };
    const one = storyCard("one", { scale: "compact" });
    const two = storyCard("two", {
      identityEnabled: true,
      identityName: "A speaker",
      identityPlacement: "media",
      identityFormat: "stacked",
      avatarDisplay: "initials",
    });
    await setCardLayout(args, [one, two]);
    await render(
      <template>
        <div class="card-allocation" style="width: 1080px">
          <BlockOutlet @name="hero-blocks" />
        </div>
      </template>
    );
    await settleCardLayout();
    const initialHeight = cardRegion("one", "media").offsetHeight;
    const allocation = find(".card-allocation");

    for (const direction of ["ltr", "rtl"]) {
      allocation.dir = direction;
      allocation.style.fontSize = "200%";
      allocation.style.setProperty("--space-4", "40px");
      await setCardLayout(args, [
        one,
        {
          ...two,
          args: {
            ...two.args,
            identityRole: "Researcher and community organizer. ".repeat(12),
            body: "An expanded description. ".repeat(12),
          },
        },
      ]);
      await settleCardLayout();
      assert.deepEqual(
        findAll(".d-block-layout__flex > [data-block-id]").map(
          (item) => item.dataset.blockId
        ),
        ["two", "one"],
        `${direction}: reversal changes reading order without changing the source`
      );
      assert.true(
        cardRegion("one", "media").offsetHeight > initialHeight + 100,
        `${direction}: the peer grows for the expanded media identity`
      );
      assert.closeTo(
        cardRegion("one", "media").getBoundingClientRect().bottom,
        cardRegion("two", "media").getBoundingClientRect().bottom,
        1,
        `${direction}: the media seam stays aligned after text zoom`
      );
      assert.closeTo(
        cardRegion("one", "actions").getBoundingClientRect().bottom,
        cardRegion("two", "actions").getBoundingClientRect().bottom,
        1,
        `${direction}: different spacing tokens retain aligned action edges`
      );
      const identity = cardRegion("two", "identity").getBoundingClientRect();
      const media = cardRegion("two", "media").getBoundingClientRect();
      assert.true(
        identity.top >= media.top,
        `${direction}: expanded identity starts inside its artwork region`
      );
      assert.true(
        identity.bottom <= media.bottom,
        `${direction}: expanded identity ends inside its artwork region`
      );
      await setCardLayout(args, [one, two]);
      allocation.style.removeProperty("font-size");
      allocation.style.removeProperty("--space-4");
      await settleCardLayout();
      assert.closeTo(
        cardRegion("one", "media").offsetHeight,
        initialHeight,
        1,
        `${direction}: restoring the content and theme releases the extra height`
      );
    }
  });

  test("Card peers realign when a late font changes the media identity's natural height", async function (assert) {
    const font = new FontFace(
      "CardLateFont",
      'url("/fonts/RobotoMono-Regular.woff2")'
    );
    await setCardLayout({ mode: "row", autoCollapse: "never" }, [
      storyCard("one", { scale: "compact" }),
      storyCard("two", {
        identityEnabled: true,
        identityName: "An author",
        identityRole: "ill ill ill ill ill ".repeat(24),
        identityPlacement: "media",
        avatarDisplay: "none",
      }),
    ]);
    try {
      await render(
        <template>
          <div
            style="width: 880px; font-family: CardLateFont, sans-serif; font-size: 20px"
          ><BlockOutlet @name="hero-blocks" /></div>
        </template>
      );
      await settleCardLayout();
      const initialHeight = cardRegion("one", "media").offsetHeight;
      await font.load();
      document.fonts.add(font);
      await document.fonts.ready;
      await waitUntil(
        () => cardRegion("one", "media").offsetHeight > initialHeight + 80
      );
      await settleCardLayout();
      assert.closeTo(
        cardRegion("one", "media").getBoundingClientRect().bottom,
        cardRegion("two", "media").getBoundingClientRect().bottom,
        1,
        "the peer's media seam follows the newly available font"
      );
      assert.closeTo(
        cardRegion("one", "actions").getBoundingClientRect().bottom,
        cardRegion("two", "actions").getBoundingClientRect().bottom,
        1,
        "different scales retain aligned actions after font loading"
      );
      assert.true(
        cardRegion("two", "identity").getBoundingClientRect().bottom <=
          cardRegion("two", "media").getBoundingClientRect().bottom,
        "the reflowed identity remains inside its media region"
      );
      document.fonts.delete(font);
      await waitUntil(
        () =>
          Math.abs(cardRegion("one", "media").offsetHeight - initialHeight) < 2
      );
      assert.closeTo(
        cardRegion("one", "media").getBoundingClientRect().bottom,
        cardRegion("two", "media").getBoundingClientRect().bottom,
        1,
        "removing the font restores natural sizing without leaving a stale seam"
      );
    } finally {
      document.fonts.delete(font);
    }
  });

  test("Row cards respect explicit growth and cross-axis alignment", async function (assert) {
    const fixed = storyCard("fixed", { body: "Short copy" });
    fixed.containerArgs = { row: { flexGrow: 0, alignSelf: "start" } };
    const growing = storyCard("growing", { body: "Long copy. ".repeat(40) });
    growing.containerArgs = { row: { flexGrow: 2, alignSelf: "stretch" } };
    await setCardLayout({ mode: "row", autoCollapse: "never" }, [
      fixed,
      growing,
    ]);
    await render(
      <template>
        <div style="width: 888px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    const fixedCard = find("[data-block-id='fixed']");
    const growingCard = find("[data-block-id='growing']");
    assert.strictEqual(getComputedStyle(fixedCard).flexGrow, "0");
    assert.strictEqual(getComputedStyle(growingCard).flexGrow, "2");
    assert.strictEqual(getComputedStyle(fixedCard).alignSelf, "start");
    assert.true(growingCard.offsetWidth > fixedCard.offsetWidth + 100);
    assert.true(fixedCard.offsetHeight < growingCard.offsetHeight);
    assert
      .dom("[data-card-aligned]")
      .doesNotExist("non-stretched peers keep natural content heights");
  });

  test("a non-card sibling does not prevent direct Card peers from aligning", async function (assert) {
    await setCardLayout(
      { mode: "grid", columns: 3, rows: 1, autoCollapse: "never" },
      [
        {
          block: Heading,
          args: { text: "Stories" },
          containerArgs: { grid: { column: "1", row: "1" } },
        },
        storyCard("one", { scale: "compact" }, { column: "2", row: "1" }),
        storyCard(
          "two",
          { body: "Long copy. ".repeat(10), scale: "featured" },
          { column: "3", row: "1" }
        ),
      ]
    );
    await render(
      <template>
        <div style="width: 1080px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    assert.closeTo(
      cardRegion("one", "media").getBoundingClientRect().bottom,
      cardRegion("two", "media").getBoundingClientRect().bottom,
      1,
      "unrelated heading does not choose the Card presentation"
    );
  });

  test("position-only placement changes regroup existing cards without sustained reads or writes", async function (assert) {
    await setCardLayout(
      {
        mode: "grid",
        columns: 3,
        rows: 2,
        rowHeight: "700px",
        autoCollapse: "never",
      },
      [
        storyCard("one", { scale: "compact" }, { column: "1", row: "1" }),
        storyCard("two", { scale: "featured" }, { column: "2 / 4", row: "1" }),
        storyCard("three", { scale: "compact" }, { column: "1", row: "2" }),
        storyCard("four", { scale: "compact" }, { column: "2 / 4", row: "2" }),
      ]
    );
    await render(
      <template>
        <div style="width: 1080px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    const two = cardRegion("two", "media").closest(".d-block-layout__cell");
    const four = cardRegion("four", "media").closest(".d-block-layout__cell");
    const measurements = sinon.spy(two, "getBoundingClientRect");
    const original = [
      two.offsetWidth,
      two.offsetHeight,
      four.offsetWidth,
      four.offsetHeight,
    ];
    two.style.setProperty("--d-block-cell-row", "2");
    four.style.setProperty("--d-block-cell-row", "1");
    await settleCardLayout();
    assert.true(
      measurements.called,
      "placement invalidation measures the existing allocation"
    );
    assert.deepEqual(
      [two.offsetWidth, two.offsetHeight, four.offsetWidth, four.offsetHeight],
      original,
      "only positions changed"
    );
    assert.closeTo(
      cardRegion("three", "actions").getBoundingClientRect().bottom,
      cardRegion("two", "actions").getBoundingClientRect().bottom,
      1,
      "new peers share the larger trailing inset"
    );
    assert.closeTo(
      cardRegion("one", "actions").getBoundingClientRect().bottom,
      cardRegion("four", "actions").getBoundingClientRect().bottom,
      1,
      "old row releases the larger inset"
    );
    let writes = 0;
    const observer = new MutationObserver((records) => {
      writes += records.length;
    });
    findAll(".d-block-card").forEach((card) =>
      observer.observe(card, { attributes: true, attributeFilter: ["style"] })
    );
    try {
      measurements.resetHistory();
      for (let frame = 0; frame < 8; frame++) {
        await new Promise(requestAnimationFrame);
      }
      assert.strictEqual(
        writes,
        0,
        "settled geometry does not rewrite aligned dimensions"
      );
      assert.strictEqual(
        measurements.callCount,
        0,
        "settled geometry does not keep measuring allocations"
      );
    } finally {
      measurements.restore();
      observer.disconnect();
    }
  });

  test("matching grid peers share media seams and trailing action edges across unequal widths and scales", async function (assert) {
    const children = [
      storyCard(
        "one",
        { title: "A short story", scale: "compact" },
        { column: "1", row: "1" }
      ),
      storyCard(
        "two",
        {
          title: "A much longer story with room for its complete title",
          body: "Full body text. ".repeat(12),
          scale: "featured",
        },
        { column: "2 / 4", row: "1" }
      ),
    ];
    const args = {
      mode: "grid",
      columns: 3,
      rows: 1,
      autoCollapse: "never",
      cardAlignment: "auto",
    };
    await setCardLayout(args, children);
    await render(
      <template>
        <div style="width: 1080px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    assert.closeTo(
      cardRegion("one", "media").getBoundingClientRect().bottom,
      cardRegion("two", "media").getBoundingClientRect().bottom,
      1,
      "unequal widths have one media seam"
    );
    assert.closeTo(
      cardRegion("one", "actions").getBoundingClientRect().bottom,
      cardRegion("two", "actions").getBoundingClientRect().bottom,
      1,
      "different padding does not shift action edges"
    );
    await setCardLayout({ ...args, cardAlignment: "off" }, children);
    await settleCardLayout();
    assert
      .dom("[data-block-id='one'] .d-block-card")
      .doesNotHaveAttribute(
        "data-card-aligned",
        "opt-out releases transient coordination"
      );
    assert.notStrictEqual(
      cardRegion("one", "media").getBoundingClientRect().height,
      cardRegion("two", "media").getBoundingClientRect().height,
      "natural widths own their media preferences again"
    );
  });

  test("independent rows release after a presentation change and do not enroll a tall editorial span", async function (assert) {
    const children = [
      storyCard(
        "curator",
        { title: "Meet our curator", presentation: "behind" },
        { column: "1", row: "1 / 3" }
      ),
      storyCard("one", { scale: "compact" }, { column: "2", row: "1" }),
      storyCard(
        "two",
        { body: "Long body. ".repeat(20), scale: "featured" },
        { column: "3", row: "1" }
      ),
      storyCard("three", {}, { column: "2", row: "2" }),
      storyCard("four", { body: "Short body" }, { column: "3", row: "2" }),
    ];
    const args = { mode: "grid", columns: 3, rows: 2, autoCollapse: "never" };
    await setCardLayout(args, children);
    await render(
      <template>
        <div style="width: 1080px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    assert.closeTo(
      cardRegion("one", "media").getBoundingClientRect().bottom,
      cardRegion("two", "media").getBoundingClientRect().bottom,
      1,
      "the first story row aligns"
    );
    assert.closeTo(
      cardRegion("three", "media").getBoundingClientRect().bottom,
      cardRegion("four", "media").getBoundingClientRect().bottom,
      1,
      "the second story row aligns independently"
    );
    assert.true(
      cardRegion("one", "content").offsetHeight >
        cardRegion("three", "content").offsetHeight,
      "long copy does not inflate the other row"
    );
    assert
      .dom("[data-block-id='curator'] .d-block-card")
      .doesNotHaveAttribute(
        "data-card-aligned",
        "row-spanning editorial Card is not enrolled"
      );
    await setCardLayout(
      args,
      children.map((child) =>
        child.id === "two"
          ? { ...child, args: { ...child.args, presentation: "below" } }
          : child
      )
    );
    await settleCardLayout();
    assert
      .dom("[data-block-id='one'] .d-block-card")
      .doesNotHaveAttribute(
        "data-card-aligned",
        "mixed-presentation row releases"
      );
    assert
      .dom("[data-block-id='four'] .d-block-card")
      .hasAttribute("data-card-aligned", "", "unrelated row remains aligned");
  });

  test("Stack releases alignment and preserves the parent's allocation and source data", async function (assert) {
    const children = [
      storyCard("one", { scale: "compact" }),
      storyCard("two", { body: "Long copy. ".repeat(15) }),
    ];
    const original = structuredClone(children.map((child) => child.args));
    await setCardLayout(
      { mode: "grid", columns: 2, rows: 1, autoCollapse: "never" },
      children
    );
    await render(
      <template>
        <div style="width: 800px"><BlockOutlet @name="hero-blocks" /></div>
      </template>
    );
    await settleCardLayout();
    assert
      .dom("[data-block-id='one'] .d-block-card")
      .hasAttribute("data-card-aligned", "", "grid peers enroll");
    await setCardLayout({ mode: "stack" }, children);
    await settleCardLayout();
    assert
      .dom("[data-card-aligned]")
      .doesNotExist("Stack has no row coordination");
    assert.true(
      cardRegion("two", "media").getBoundingClientRect().top >
        cardRegion("one", "content").getBoundingClientRect().bottom,
      "cards stack in authored order"
    );
    assert.deepEqual(
      children.map((child) => child.args),
      original,
      "no measured dimensions enter source data"
    );
  });
});
