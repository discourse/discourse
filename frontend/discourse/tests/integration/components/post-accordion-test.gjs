import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import DPostAccordion from "discourse/ui-kit/d-post-accordion";

module("Integration | Component | DPostAccordion", function (hooks) {
  setupRenderingTest(hooks);

  const posts = [
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

  test("renders posts with default metadata section", async function (assert) {
    await render(<template><DPostAccordion @posts={{posts}} /></template>);

    assert.dom(".d-post-accordion").exists();
    assert.dom(".d-post-accordion-item").exists({ count: 2 });
    assert.dom(".d-post-accordion-item__header").exists({ count: 2 });
    assert.dom(".d-post-accordion-item__body").exists({ count: 2 });
    assert.dom(".d-post-accordion-item__content").exists({ count: 2 });
    assert.dom(".d-post-accordion-item__read-more").exists({ count: 2 });

    assert
      .dom(":nth-child(1 of .d-post-accordion-item) .read-more-link")
      .hasAttribute("href", posts[0].url);
    assert
      .dom(":nth-child(1 of .d-post-accordion-item) .date-link")
      .hasAttribute("href", posts[0].url);
    assert
      .dom(":nth-child(2 of .d-post-accordion-item) .read-more-link")
      .hasAttribute("href", posts[1].url);
    assert
      .dom(":nth-child(2 of .d-post-accordion-item) .date-link")
      .hasAttribute("href", posts[1].url);
  });

  test("date link is announced with an abbreviated date instead of the full date and time", async function (assert) {
    const clock = fakeTime("2026-07-13T12:00:00", null, true);

    try {
      const recentPosts = [
        { ...posts[0], created_at: moment().subtract(2, "days").toISOString() },
      ];

      await render(
        <template><DPostAccordion @posts={{recentPosts}} /></template>
      );

      assert.dom(".date-link").hasAria("label", "2 days ago");
      assert
        .dom(".date-link > span[aria-hidden=true] .relative-date")
        .exists("the relative date and its tooltip are accessibility-hidden");
    } finally {
      clock.restore();
    }
  });

  test("yields custom header", async function (assert) {
    await render(
      <template>
        <DPostAccordion @posts={{posts}}>
          <:header>
            <div class="custom-header">Header content</div>
          </:header>
        </DPostAccordion>
      </template>
    );

    assert.dom(".d-post-accordion__header .custom-header").exists();
    assert
      .dom(".d-post-accordion__header .custom-header")
      .hasText("Header content");
  });

  test("yields custom itemMetadata, replacing the default", async function (assert) {
    await render(
      <template>
        <DPostAccordion @posts={{posts}}>
          <:itemMetadata>
            <div class="custom-metadata">Metadata content</div>
          </:itemMetadata>
        </DPostAccordion>
      </template>
    );

    assert.dom(".d-post-accordion-item__metadata").exists({ count: 2 });
    assert.dom(".d-post-accordion-item__metadata .custom-metadata").exists();
    assert
      .dom(".d-post-accordion-item__metadata .custom-metadata")
      .hasText("Metadata content");
    assert.dom(".d-post-accordion-item__metadata .user-link").doesNotExist();
    assert.dom(".d-post-accordion-item__metadata .date-link").doesNotExist();
  });

  test("yields custom beforeItemContent", async function (assert) {
    await render(
      <template>
        <DPostAccordion @posts={{posts}}>
          <:beforeItemContent>
            <div class="custom-before-content">Before content</div>
          </:beforeItemContent>
        </DPostAccordion>
      </template>
    );

    assert
      .dom(".d-post-accordion-item__content .custom-before-content")
      .exists({ count: 2 });
  });

  test("handles empty posts array", async function (assert) {
    const emptyPosts = [];

    await render(<template><DPostAccordion @posts={{emptyPosts}} /></template>);

    assert.dom(".d-post-accordion").doesNotExist();
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
      <template><DPostAccordion @posts={{postsWithoutContent}} /></template>
    );

    assert.dom(".d-post-accordion-item--has-content").doesNotExist();
    assert.dom(".d-post-accordion-item__body").doesNotExist();
    assert.dom(".d-post-accordion-item__jump").exists();
    assert
      .dom(".d-post-accordion-item__jump")
      .hasAttribute("href", postsWithoutContent[0].url);
  });

  test("first post is expanded by default, others are collapsed", async function (assert) {
    await render(<template><DPostAccordion @posts={{posts}} /></template>);

    assert
      .dom(":nth-child(1 of .d-post-accordion-item)")
      .hasAttribute("data-expanded");

    assert
      .dom(":nth-child(2 of .d-post-accordion-item)")
      .doesNotHaveAttribute("data-expanded");
  });

  test("toggle button expands collapsed post and collapses expanded post", async function (assert) {
    await render(<template><DPostAccordion @posts={{posts}} /></template>);

    const firstItem = ":nth-child(1 of .d-post-accordion-item)";
    const secondItem = ":nth-child(2 of .d-post-accordion-item)";

    await click(`${secondItem} .d-post-accordion-item__toggle`);
    assert.dom(secondItem).hasAttribute("data-expanded");
    assert.dom(firstItem).hasAttribute("data-expanded");

    await click(`${firstItem} .d-post-accordion-item__toggle`);
    assert.dom(firstItem).doesNotHaveAttribute("data-expanded");
    assert.dom(secondItem).hasAttribute("data-expanded");
  });

  const fiveLinePost = [
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

  test("post is truncated if longer than linesDisplayed", async function (assert) {
    await render(
      <template>
        <DPostAccordion @posts={{fiveLinePost}} @linesDisplayed="2" />
      </template>
    );

    assert
      .dom(".d-post-accordion-item")
      .hasAttribute("data-overflowing", "true");
  });

  test("post is not truncated if shorter than linesDisplayed", async function (assert) {
    await render(
      <template>
        <DPostAccordion @posts={{fiveLinePost}} @linesDisplayed="10" />
      </template>
    );

    await waitFor(".d-post-accordion-item[data-overflowing='false']");

    assert
      .dom(".d-post-accordion-item")
      .hasAttribute("data-overflowing", "false");
  });
});
