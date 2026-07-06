import { render, settled, waitFor } from "@ember/test-helpers";
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
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

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

  test("resolves and renders a fetched topic", async function (assert) {
    pretender.get("/t/42.json", () =>
      response({
        id: 42,
        slug: "welcome",
        title: "Welcome",
        fancy_title: "Welcome",
        category_id: null,
        image_url: "/uploads/topic.png",
        post_stream: { posts: [{ cooked: "<p>An intro paragraph</p>" }] },
      })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 42 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-topic-card__title");
    await settled();

    assert
      .dom(".d-block-topic-card__title")
      .hasText("Welcome", "renders the fetched topic's title");
    assert
      .dom(".d-block-topic-card .d-block-stretched-link")
      .hasAttribute("href", "/t/welcome/42", "links to the fetched topic");
  });

  test("shows a structural skeleton while the topic loads", async function (assert) {
    let resolveRequest;
    pretender.get(
      "/t/42.json",
      () =>
        new Promise((resolve) => {
          resolveRequest = () =>
            resolve(
              response({
                id: 42,
                slug: "welcome",
                title: "Welcome",
                fancy_title: "Welcome",
                category_id: null,
                image_url: null,
                post_stream: { posts: [{ cooked: "<p>Body</p>" }] },
              })
            );
        })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 42 } },
      ])
    );

    // The pending request keeps the run loop busy, so wait for the rendered
    // skeleton DOM rather than for `render` to settle.
    const renderPromise = render(
      <template><BlockOutlet @name="hero-blocks" /></template>
    );

    await waitFor(".d-block-topic-card__skeleton");
    assert
      .dom(".d-block-topic-card__skeleton .d-skeleton__item")
      .exists("shows low-fidelity skeleton bars while loading");
    assert
      .dom(".d-block-topic-card .d-block-stretched-link")
      .doesNotExist("no resolved content while loading");

    resolveRequest();
    await renderPromise;
    await settled();

    assert
      .dom(".d-block-topic-card__skeleton")
      .doesNotExist("the skeleton is gone once the topic resolves");
    assert
      .dom(".d-block-topic-card__title")
      .hasText("Welcome", "the resolved topic replaces the skeleton");
  });

  test("renders an empty box, not a configuration prompt, when no topic is configured", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: TopicCard, args: {} }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-topic-card__empty");
    await settled();

    assert
      .dom(".d-block-topic-card__empty")
      .exists("shows the empty placeholder")
      .hasText("", "renders no configuration prompt on the render path");
    assert
      .dom(".d-block-topic-card__unavailable")
      .doesNotExist("an unconfigured card is empty, not an error");
  });

  test("renders the unavailable message when the topic fails to load", async function (assert) {
    pretender.get("/t/7.json", () => response(404, {}));

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 7 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-topic-card__unavailable");
    await settled();

    assert
      .dom(".d-block-topic-card__unavailable")
      .hasText(
        i18n("blocks.builtin.topic_card.unavailable"),
        "surfaces a neutral end-user message, not the raw error"
      );
    assert
      .dom(".d-block-topic-card__empty")
      .doesNotExist("a failed load is an error, not empty");
  });

  test("renders nothing on failure when hideWhenUnavailable is set", async function (assert) {
    pretender.get("/t/7.json", () => response(404, {}));

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 7, hideWhenUnavailable: true } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-topic-card__skeleton")
      .doesNotExist("the load has settled past the skeleton");
    assert
      .dom(".d-block-topic-card__unavailable")
      .doesNotExist("suppresses the message when told to hide");
    assert
      .dom(".d-block-topic-card__title")
      .doesNotExist("no topic content rendered on failure");
  });
});
