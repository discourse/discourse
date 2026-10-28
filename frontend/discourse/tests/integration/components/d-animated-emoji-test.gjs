import { render, triggerEvent } from "@ember/test-helpers";
import { registerEmoji } from "pretty-text/emoji";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DAnimatedEmoji from "discourse/ui-kit/d-animated-emoji";

module("Integration | ui-kit | DAnimatedEmoji", function (hooks) {
  setupRenderingTest(hooks);

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

  test("animates skin tones", async function (assert) {
    await render(<template><DAnimatedEmoji @code="clap:t3" /></template>);

    assert
      .dom(".d-animated-emoji source")
      .hasAttribute("srcset", `/images/emoji/noto_animated/clap/3.avif?v=${v}`);
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

  test("falls back to the static image when the emoji has no animation", async function (assert) {
    await render(
      <template>
        <DAnimatedEmoji @code="thinking" />
        <DAnimatedEmoji @code="thinking" />
      </template>
    );

    const image = document.querySelector(".d-animated-emoji img");
    Object.defineProperty(image, "currentSrc", {
      value: `${location.origin}/images/emoji/noto_animated/thinking.avif?v=${v}`,
    });
    await triggerEvent(image, "error");

    assert
      .dom(".d-animated-emoji source")
      .doesNotExist("every instance stops requesting the missing animation");
  });
});
