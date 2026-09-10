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

// Stubs the list endpoint the cards batch through, recording each request so
// tests can assert how many were made and which ids they carried.
function stubTopicList(topics) {
  const requests = [];

  pretender.get("/latest.json", (request) => {
    requests.push(request.queryParams);

    const requestedIds = (request.queryParams.topic_ids ?? "")
      .split(",")
      .map((id) => parseInt(id, 10));

    return response({
      topic_list: {
        topics: topics.filter((topic) => requestedIds.includes(topic.id)),
      },
    });
  });

  return requests;
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

  test("renders the excerpt as the server's markup, not escaped source", async function (assert) {
    preloadCard(7, {
      id: 7,
      url: "/t/guide/7",
      title: "Guide",
      fancyTitle: "Guide",
      categoryBadge: null,
      imageUrl: null,
      excerpt: "Shipping :tada: today&hellip;",
    });

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 7 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-topic-card__excerpt img.emoji")
      .exists("renders the emoji shortcode as an image");
    assert
      .dom(".d-block-topic-card__excerpt")
      .hasText("Shipping today…", "resolves the entity instead of printing it");
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
    stubTopicList([
      {
        id: 42,
        slug: "welcome",
        title: "Welcome",
        fancy_title: "Welcome",
        category_id: null,
        image_url: "/uploads/topic.png",
        excerpt: "An intro paragraph",
      },
    ]);

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

  test("every card on the page resolves through one combined request", async function (assert) {
    const requests = stubTopicList([
      {
        id: 1,
        slug: "first",
        title: "First",
        fancy_title: "First",
        category_id: null,
        image_url: null,
        excerpt: null,
      },
      {
        id: 2,
        slug: "second",
        title: "Second",
        fancy_title: "Second",
        category_id: null,
        image_url: null,
        excerpt: null,
      },
    ]);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 1 } },
        { block: TopicCard, args: { topicId: 2 } },
        // Repeats an id already in the window, and asks for a topic the
        // response won't carry.
        { block: TopicCard, args: { topicId: 1 } },
        { block: TopicCard, args: { topicId: 3 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-topic-card__title");
    await settled();

    assert.strictEqual(requests.length, 1, "made a single combined request");
    assert.strictEqual(
      requests[0].topic_ids,
      "1,2,3",
      "carried each distinct id once"
    );
    assert.strictEqual(
      requests[0].include_excerpts,
      "true",
      "asked the endpoint to serialize excerpts"
    );

    assert
      .dom(".d-block-topic-card__title")
      .exists({ count: 3 }, "paints every card the response carried");
    assert
      .dom(".d-block-topic-card__empty")
      .exists({ count: 1 }, "the topic the response omitted renders empty");
    assert
      .dom(".d-block-topic-card__unavailable")
      .doesNotExist("a missing topic never fails its neighbours");
  });

  test("shows a structural skeleton while the topic loads", async function (assert) {
    let resolveRequest;
    pretender.get(
      "/latest.json",
      () =>
        new Promise((resolve) => {
          resolveRequest = () =>
            resolve(
              response({
                topic_list: {
                  topics: [
                    {
                      id: 42,
                      slug: "welcome",
                      title: "Welcome",
                      fancy_title: "Welcome",
                      category_id: null,
                      image_url: null,
                      excerpt: "Body",
                    },
                  ],
                },
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
    const requests = stubTopicList([]);

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
    assert.strictEqual(
      requests.length,
      0,
      "an unconfigured card asks the endpoint for nothing"
    );
  });

  test("renders the unavailable message when the topic fails to load", async function (assert) {
    pretender.get("/latest.json", () => response(500, {}));

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

  test("renders an empty box when the response omits the topic", async function (assert) {
    stubTopicList([]);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: TopicCard, args: { topicId: 7 } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-topic-card__empty");
    await settled();

    // The list drops topics the viewer muted, and a muted topic should go quiet
    // rather than announce itself as broken.
    assert
      .dom(".d-block-topic-card__empty")
      .exists("an unresolved topic renders the empty placeholder")
      .hasText("", "says nothing about the topic it could not resolve");
    assert
      .dom(".d-block-topic-card__unavailable")
      .doesNotExist("only a failed request reads as unavailable");
  });

  test("renders nothing on failure when hideWhenUnavailable is set", async function (assert) {
    pretender.get("/latest.json", () => response(500, {}));

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
