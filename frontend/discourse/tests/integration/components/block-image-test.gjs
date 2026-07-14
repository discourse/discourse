import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Image from "discourse/blocks/builtin/image";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const LIGHT_IMG = { url: "/uploads/light.png", width: 400, height: 300 };
const DARK_IMG = { url: "/uploads/dark.png", width: 400, height: 300 };

module("Integration | Blocks | image", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    const session = getOwner(this).lookup("service:session");
    session.set("darkModeAvailable", null);
    session.set("defaultColorSchemeIsDark", null);
  });

  test("declares image as a required arg", function (assert) {
    // The render-time check (`validateArgsAgainstSchema` in
    // `lib/blocks/-internals/validation/args.js`) throws a `BlockError`
    // when `entry.args.image` is missing, which edit tooling's permissive
    // layer surfaces as a validation error. We assert the schema
    // declaration directly rather than triggering the render-time path,
    // because the rejection happens inside a tracked async getter and
    // escapes `assert.rejects`.
    const metadata = getBlockMetadata(Image);
    assert.true(
      metadata?.args?.image?.required,
      "image arg is marked required: true"
    );
  });

  test("renders a plain image when only the light variant is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: Image, args: { image: LIGHT_IMG, alt: "Light" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom("img.d-block-image").exists();
    assert.dom("picture").doesNotExist("no <picture> when there's no dark img");
  });

  test("renders a <picture> with a dark <source> when both variants are set", async function (assert) {
    const session = getOwner(this).lookup("service:session");
    session.set("darkModeAvailable", true);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Image,
          args: {
            image: { ...LIGHT_IMG, dark: DARK_IMG },
            alt: "Both",
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom("picture").exists();
    assert
      .dom("picture source")
      .hasAttribute("srcset", /dark\.png/, "dark variant routed to <source>");
    assert
      .dom("picture img")
      .hasAttribute("src", /light\.png/, "light variant remains the fallback");
  });

  test("wraps the image in an anchor when link is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Image,
          args: { image: LIGHT_IMG, link: "https://example.com" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("a.d-block-image")
      .exists()
      .hasAttribute("href", "https://example.com");
    assert.dom("a.d-block-image img").exists("image is the anchor's child");
  });

  test("wraps the image in a figure with figcaption when caption is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Image,
          args: { image: LIGHT_IMG, caption: "A nice photo" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom("figure.d-block-image").exists();
    assert.dom("figure.d-block-image img").exists();
    assert
      .dom("figure.d-block-image figcaption.d-block-image__caption")
      .hasText("A nice photo");
  });

  test("supports caption + link together", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Image,
          args: {
            image: LIGHT_IMG,
            link: "https://example.com",
            caption: "Captioned link",
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom("figure.d-block-image").exists();
    assert
      .dom("figure.d-block-image > a")
      .exists("anchor wraps the image, inside the figure");
    assert
      .dom("figure.d-block-image > figcaption")
      .exists("caption sits next to the anchor");
  });
});
