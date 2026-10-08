import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Embed from "discourse/blocks/builtin/embed";
import Icon from "discourse/blocks/builtin/icon";
import Quote from "discourse/blocks/builtin/quote";
import Video from "discourse/blocks/builtin/video";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | media leaves", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("icon renders the chosen glyph and links when an href is set", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: Icon, args: { icon: "heart", href: "/love" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("a.d-block-icon")
      .hasAttribute("href", "/love", "renders a link when href is set");
    assert
      .dom(".d-block-icon .d-icon-heart")
      .exists("renders the chosen icon glyph");
  });

  test("quote renders the passage and attribution", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: Quote,
          args: { content: "It changed everything", attribution: "Ada" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-quote__content").hasText("It changed everything");
    assert.dom(".d-block-quote__attribution").hasText("Ada");
  });

  test("video renders a player with the source and controls", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: Video, args: { source: "/clip.mp4" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("video.d-block-video")
      .hasAttribute("src", "/clip.mp4")
      .hasAttribute("controls");
  });

  test("embed renders supplied HTML", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: Embed, args: { html: "<p class='embedded'>Hello</p>" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-embed .embedded").hasText("Hello");
  });
});
