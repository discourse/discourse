import { render } from "@ember/test-helpers";
import { registerEmoji } from "pretty-text/emoji";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DAnimatedEmoji from "discourse/ui-kit/d-animated-emoji";

module("Integration | ui-kit | DAnimatedEmoji", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis.json", () =>
      response({
        "smileys_&_emotion": [
          { name: "wink", animated: true },
          { name: "+1", tonable: true, animated: true },
        ],
        objects: [{ name: "abacus", animated: false }],
      })
    );
  });

  test("offers the animation, keeping the static image as fallback", async function (assert) {
    await render(<template><DAnimatedEmoji @code="Wink" /></template>);

    assert
      .dom(".d-animated-emoji source")
      .hasAttribute("srcset", `/images/emoji/noto_animated/wink.avif?v=${v}`)
      .hasAttribute("media", "(prefers-reduced-motion: no-preference)");
    assert
      .dom(".d-animated-emoji img.emoji")
      .hasAttribute("src", `/images/emoji/twitter/wink.png?v=${v}`)
      .hasAttribute("alt", "wink")
      .hasAttribute("title", "wink");
  });

  test("animates skin tones and alternate names", async function (assert) {
    await render(
      <template>
        <DAnimatedEmoji class="toned" @code="+1:t3" />
        <DAnimatedEmoji class="alias" @code="thumbsup" />
      </template>
    );

    assert
      .dom(".d-animated-emoji:has(.toned) source")
      .hasAttribute("srcset", `/images/emoji/noto_animated/+1/3.avif?v=${v}`);
    assert
      .dom(".d-animated-emoji:has(.alias) source")
      .hasAttribute(
        "srcset",
        `/images/emoji/noto_animated/thumbsup.avif?v=${v}`
      );
  });

  test("uses the given title", async function (assert) {
    await render(
      <template><DAnimatedEmoji @code="wink" @title="Winking" /></template>
    );

    assert
      .dom(".d-animated-emoji img")
      .hasAttribute("alt", "Winking")
      .hasAttribute("title", "Winking");
  });

  test("renders emojis without an animation static", async function (assert) {
    await render(<template><DAnimatedEmoji @code="abacus" /></template>);

    assert.dom(".d-animated-emoji source").doesNotExist();
    assert
      .dom(".d-animated-emoji img")
      .hasAttribute("src", `/images/emoji/twitter/abacus.png?v=${v}`);
  });

  test("renders static when the emoji list fails to load", async function (assert) {
    pretender.get("/emojis.json", () => response(500, {}));

    await render(<template><DAnimatedEmoji @code="wink" /></template>);

    assert.dom(".d-animated-emoji source").doesNotExist();
    assert.dom(".d-animated-emoji img").exists();
  });

  test("renders custom emojis static", async function (assert) {
    registerEmoji("d_animated_emoji_parrot", "/uploads/parrot.gif");

    await render(
      <template><DAnimatedEmoji @code="d_animated_emoji_parrot" /></template>
    );

    assert.dom(".d-animated-emoji source").doesNotExist();
    assert
      .dom(".d-animated-emoji img")
      .hasAttribute("src", `/uploads/parrot.gif?v=${v}`);
  });

  test("renders nothing for an unknown emoji or with emojis disabled", async function (assert) {
    await render(<template><DAnimatedEmoji @code="not_an_emoji" /></template>);
    assert.dom(".d-animated-emoji").doesNotExist();

    this.siteSettings.enable_emoji = false;
    await render(<template><DAnimatedEmoji @code="wink" /></template>);
    assert.dom(".d-animated-emoji").doesNotExist();
  });
});
