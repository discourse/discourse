import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import MediaCard from "discourse/blocks/builtin/media-card";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const AVATAR = { url: "/uploads/avatar.png", width: 100, height: 100 };
const IMAGE = { url: "/uploads/bg.png", width: 800, height: 400 };

// Required text args, so the block clears render-time schema validation
// regardless of the image args we're exercising.
const REQUIRED_TEXT = {
  badgeLabel: "Featured",
  title: "A headline",
  ctaLabel: "Learn more",
  ctaHref: "https://example.com",
};

module("Integration | Blocks | media-card", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("exposes the background image arg in the main args section, not Advanced", function (assert) {
    const metadata = getBlockMetadata(MediaCard);
    assert.strictEqual(
      metadata?.args?.image?.ui?.group,
      undefined,
      "the background image arg is not tucked into the Advanced group"
    );
    assert.strictEqual(
      metadata?.args?.backgroundColor?.ui?.group,
      "Advanced",
      "backgroundColor stays in the Advanced group"
    );
  });

  test("renders the full card and persistent image markers when both images are empty", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: MediaCard, args: { ...REQUIRED_TEXT } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // The composite card still renders its real layout — it must NOT be
    // replaced by stacked image placeholders.
    assert.dom(".d-block-media-card").exists("the card itself renders");
    assert
      .dom(".d-block-media-card__identity")
      .exists("identity region renders");
    assert.dom(".d-block-media-card__title").exists("title wrapper renders");
    assert.dom(".d-block-media-card__cta").exists("cta wrapper renders");

    // Both image args expose a persistent marker edit tooling can anchor a
    // drop target to, even though neither carries a URL.
    assert
      .dom(".d-block-media-card__avatar--empty[data-block-arg='avatar']")
      .exists("avatar arg has a persistent empty slot marker");
    assert
      .dom(".d-block-media-card__backdrop[data-block-arg='image']")
      .exists("background arg has a persistent backdrop marker");

    // No real avatar image when empty.
    assert
      .dom("img.d-block-media-card__avatar")
      .doesNotExist("no avatar <img> while empty");
  });

  test("swaps the avatar slot for an <img> when the avatar is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: MediaCard,
          args: { ...REQUIRED_TEXT, avatar: AVATAR },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("img.d-block-media-card__avatar[data-block-arg='avatar']")
      .exists("avatar renders as an <img> when a URL is set")
      .hasAttribute("src", /avatar\.png/);
    assert
      .dom(".d-block-media-card__avatar--empty")
      .doesNotExist("the empty slot is gone once the avatar is filled");
  });

  test("paints the backdrop and drops the --empty modifier when a background image is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: MediaCard,
          args: { ...REQUIRED_TEXT, image: IMAGE },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-media-card__backdrop[data-block-arg='image']")
      .exists("backdrop marker renders")
      .doesNotHaveClass(
        "d-block-media-card__backdrop--empty",
        "the --empty modifier is dropped once the background is filled"
      );
  });
});
