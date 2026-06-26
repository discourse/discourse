import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import TopicCard from "discourse/blocks/builtin/topic-card";
import {
  blockDataKey,
  resetBlockData,
} from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// Inline the resolved card data through the preload store so the data hook
// returns it without a network fetch — the resolver is bypassed when a payload
// is present for the descriptor's key.
function preloadCard(topicId, payload) {
  PreloadStore.store(
    blockDataKey("topic-card", { kind: "topic-card", topicId }),
    payload
  );
}

module("Integration | Blocks | topic-card", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    resetBlockData();
  });

  test("renders an image card with title and category, no excerpt", async function (assert) {
    preloadCard(42, {
      id: 42,
      url: "/t/welcome/42",
      title: "Welcome",
      fancyTitle: "Welcome",
      categoryBadge: "<span class='badge-category'>News</span>",
      imageUrl: "/uploads/topic.png",
      excerpt: "An excerpt that should stay hidden behind the image",
    });

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 42 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-topic-card__background")
      .exists("renders the background image element")
      .hasAttribute(
        "style",
        new RegExp("/uploads/topic\\.png"),
        "uses the topic image url"
      );
    assert
      .dom(".d-block-topic-card__title")
      .hasText("Welcome", "renders the topic title");
    assert
      .dom(".d-block-topic-card__category .badge-category")
      .exists("renders the non-link category badge");
    assert
      .dom(".d-block-topic-card__excerpt")
      .doesNotExist("hides the excerpt when an image is shown");
    assert
      .dom(".d-block-topic-card .d-block-stretched-link")
      .hasAttribute("href", "/t/welcome/42")
      .hasAttribute("aria-label", "Welcome");
  });

  test("renders an excerpt when the topic has no image", async function (assert) {
    preloadCard(7, {
      id: 7,
      url: "/t/guide/7",
      title: "Guide",
      fancyTitle: "Guide",
      categoryBadge: null,
      imageUrl: null,
      excerpt: "A helpful excerpt",
    });

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 7 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-topic-card__background")
      .doesNotExist("no background without an image");
    assert
      .dom(".d-block-topic-card__excerpt")
      .hasText("A helpful excerpt", "shows the excerpt");
  });

  test("a custom image override takes precedence over the topic image", async function (assert) {
    preloadCard(7, {
      id: 7,
      url: "/t/guide/7",
      title: "Guide",
      fancyTitle: "Guide",
      categoryBadge: null,
      imageUrl: null,
      excerpt: "A helpful excerpt",
    });

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: TopicCard,
          args: { topicId: 7, image: { url: "/uploads/override.png" } },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-topic-card__background")
      .hasAttribute(
        "style",
        new RegExp("/uploads/override\\.png"),
        "uses the override image"
      );
    assert
      .dom(".d-block-topic-card__excerpt")
      .doesNotExist("the override image suppresses the excerpt");
  });

  test("renders the empty state when the topic does not resolve", async function (assert) {
    preloadCard(99, null);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 99 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-topic-card__empty")
      .exists("shows the empty placeholder");
  });
});
