import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostExcerptAccordion from "discourse/components/post/post-excerpt-accordion";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | PostExcerptAccordion", function (hooks) {
  setupRenderingTest(hooks);

  const excerptPosts = [
    {
      id: 1,
      topic_id: 123,
      post_number: 2,
      username: "user1",
      name: "User One",
      avatar_template: "/images/avatar.png",
      cooked: "<p>First excerpt content</p>",
      url: "/t/test-topic/123/2",
      created_at: "2024-01-01T00:00:00Z",
    },
    {
      id: 2,
      topic_id: 123,
      post_number: 3,
      username: "user2",
      name: "User Two",
      avatar_template: "/images/avatar.png",
      cooked: "<p>Second excerpt content</p>",
      url: "/t/test-topic/123/3",
      created_at: "2024-01-02T00:00:00Z",
    },
  ];

  test("renders excerpt posts with default metadata section", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{excerptPosts}} />
      </template>
    );

    assert.dom(".d-post-excerpt-accordion").exists();
    assert.dom(".d-post-excerpt-accordion-item").exists({ count: 2 });
    assert.dom(".d-post-excerpt-accordion-item__header").exists({ count: 2 });
    assert.dom(".d-post-excerpt-accordion-item__body").exists({ count: 2 });
    assert.dom(".d-post-excerpt-accordion-item__content").exists({ count: 2 });
    assert
      .dom(".d-post-excerpt-accordion-item__read-more")
      .exists({ count: 2 });

    assert
      .dom(":nth-child(1 of .d-post-excerpt-accordion-item) .read-more-link")
      .hasAttribute("href", excerptPosts[0].url);
    assert
      .dom(":nth-child(1 of .d-post-excerpt-accordion-item) .date-link")
      .hasAttribute("href", excerptPosts[0].url);
    assert
      .dom(":nth-child(2 of .d-post-excerpt-accordion-item) .read-more-link")
      .hasAttribute("href", excerptPosts[1].url);
    assert
      .dom(":nth-child(2 of .d-post-excerpt-accordion-item) .date-link")
      .hasAttribute("href", excerptPosts[1].url);
  });

  test("yields custom header", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{excerptPosts}}>
          <:header>
            <div class="custom-header">Header content</div>
          </:header>
        </PostExcerptAccordion>
      </template>
    );

    assert.dom(".d-post-excerpt-accordion__header .custom-header").exists();
    assert
      .dom(".d-post-excerpt-accordion__header .custom-header")
      .hasText("Header content");
  });

  test("yields custom itemMetadata, replacing the default", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{excerptPosts}}>
          <:itemMetadata>
            <div class="custom-metadata">Metadata content</div>
          </:itemMetadata>
        </PostExcerptAccordion>
      </template>
    );

    assert.dom(".d-post-excerpt-accordion-item__metadata").exists({ count: 2 });
    assert
      .dom(".d-post-excerpt-accordion-item__metadata .custom-metadata")
      .exists();
    assert
      .dom(".d-post-excerpt-accordion-item__metadata .custom-metadata")
      .hasText("Metadata content");
    assert
      .dom(".d-post-excerpt-accordion-item__metadata .user-link")
      .doesNotExist();
    assert
      .dom(".d-post-excerpt-accordion-item__metadata .date-link")
      .doesNotExist();
  });

  test("yields custom beforeItemContent", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{excerptPosts}}>
          <:beforeItemContent>
            <div class="custom-before-content">Before content</div>
          </:beforeItemContent>
        </PostExcerptAccordion>
      </template>
    );

    assert
      .dom(".d-post-excerpt-accordion-item__content .custom-before-content")
      .exists({ count: 2 });
  });

  test("handles empty excerpt posts array", async function (assert) {
    const emptyExcerptPosts = [];

    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{emptyExcerptPosts}} />
      </template>
    );

    assert.dom(".d-post-excerpt-accordion").doesNotExist();
  });

  test("renders item without content when cooked is empty", async function (assert) {
    const postsWithoutContent = [
      {
        id: 3,
        topic_id: 123,
        post_number: 4,
        username: "user3",
        name: "User Three",
        avatar_template: "/images/avatar.png",
        cooked: null,
        url: "/t/test-topic/123/4",
        created_at: "2024-01-03T00:00:00Z",
      },
    ];

    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{postsWithoutContent}} />
      </template>
    );

    assert.dom(".d-post-excerpt-accordion-item.title-only").exists();
    assert.dom(".d-post-excerpt-accordion-item--has-excerpt").doesNotExist();
    assert.dom(".d-post-excerpt-accordion-item__body").doesNotExist();
    assert.dom(".d-post-excerpt-accordion-item__jump").exists();
    assert
      .dom(".d-post-excerpt-accordion-item__jump")
      .hasAttribute("href", postsWithoutContent[0].url);
  });

  test("first post is expanded by default, others are collapsed", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{excerptPosts}} />
      </template>
    );

    assert
      .dom(":nth-child(1 of .d-post-excerpt-accordion-item)")
      .hasAttribute("data-expanded");

    assert
      .dom(":nth-child(2 of .d-post-excerpt-accordion-item)")
      .doesNotHaveAttribute("data-expanded");
  });

  test("toggle button expands collapsed post and collapses expanded post", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion @excerptPosts={{excerptPosts}} />
      </template>
    );

    const firstItem = ":nth-child(1 of .d-post-excerpt-accordion-item)";
    const secondItem = ":nth-child(2 of .d-post-excerpt-accordion-item)";

    await click(`${secondItem} .d-post-excerpt-accordion-item__toggle`);
    assert.dom(secondItem).hasAttribute("data-expanded");
    assert.dom(firstItem).hasAttribute("data-expanded");

    await click(`${firstItem} .d-post-excerpt-accordion-item__toggle`);
    assert.dom(firstItem).doesNotHaveAttribute("data-expanded");
    assert.dom(secondItem).hasAttribute("data-expanded");
  });

  const fiveLineExcerptPost = [
    {
      id: 1,
      topic_id: 123,
      post_number: 2,
      username: "user1",
      name: "User One",
      avatar_template: "/images/avatar.png",
      cooked: "<p>Line 1<br/>Line 2<br/>Line 3<br/>Line 4<br/>Line 5</p>",
      url: "/t/test-topic/123/2",
      created_at: "2024-01-01T00:00:00Z",
    },
  ];

  test("excerpt is truncated if longer than linesDisplayed", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion
          @excerptPosts={{fiveLineExcerptPost}}
          @linesDisplayed="2"
        />
      </template>
    );

    assert
      .dom(".d-post-excerpt-accordion-item")
      .hasAttribute("data-overflowing", "true");
  });

  test("excerpt is not truncated if shorter than linesDisplayed", async function (assert) {
    await render(
      <template>
        <PostExcerptAccordion
          @excerptPosts={{fiveLineExcerptPost}}
          @linesDisplayed="10"
        />
      </template>
    );

    await waitFor(".d-post-excerpt-accordion-item[data-overflowing='false']");

    assert
      .dom(".d-post-excerpt-accordion-item")
      .hasAttribute("data-overflowing", "false");
  });
});
