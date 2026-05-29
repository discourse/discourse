import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WFMediaCard from "discourse/plugins/discourse-wireframe/discourse/blocks/wf-media-card";

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

module("Integration | Wireframe | wf:media-card block", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("renders the full card and persistent image markers when both images are empty", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: WFMediaCard, args: { ...REQUIRED_TEXT } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // The composite card still renders its real layout — it must NOT be
    // replaced by stacked image placeholders.
    assert.dom(".wf-media-card").exists("the card itself renders");
    assert.dom(".wf-media-card__identity").exists("identity region renders");
    assert.dom(".wf-media-card__title").exists("title wrapper renders");
    assert.dom(".wf-media-card__cta").exists("cta wrapper renders");

    // Both image args expose a persistent marker the chrome can anchor an
    // overlay to, even though neither carries a URL.
    assert
      .dom(".wf-media-card__avatar--empty[data-block-arg='avatar']")
      .exists("avatar arg has a persistent empty slot marker");
    assert
      .dom(".wf-media-card__backdrop[data-block-arg='image']")
      .exists("background arg has a persistent backdrop marker");

    // No real avatar image when empty.
    assert
      .dom("img.wf-media-card__avatar")
      .doesNotExist("no avatar <img> while empty");
  });

  test("swaps the avatar slot for an <img> when the avatar is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: WFMediaCard,
          args: { ...REQUIRED_TEXT, avatar: AVATAR },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("img.wf-media-card__avatar[data-block-arg='avatar']")
      .exists("avatar renders as an <img> when a URL is set")
      .hasAttribute("src", /avatar\.png/);
    assert
      .dom(".wf-media-card__avatar--empty")
      .doesNotExist("the empty slot is gone once the avatar is filled");
  });

  test("paints the backdrop and drops the --empty modifier when a background image is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: WFMediaCard,
          args: { ...REQUIRED_TEXT, image: IMAGE },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".wf-media-card__backdrop[data-block-arg='image']")
      .exists("backdrop marker renders")
      .doesNotHaveClass(
        "wf-media-card__backdrop--empty",
        "the --empty modifier is dropped once the background is filled"
      );
  });
});
