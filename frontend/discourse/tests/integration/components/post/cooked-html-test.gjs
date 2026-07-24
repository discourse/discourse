import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostCookedHtml from "discourse/components/post/cooked-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post, { highlightTerm } = {}) {
  return render(
    <template>
      <PostCookedHtml @post={{post}} @highlightTerm={{highlightTerm}} />
    </template>
  );
}

module("Integration | Component | Post | PostCookedHtml", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });
    const post = store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });

    this.post = post;
  });

  test("quotes with no username and no valid topic", async function (assert) {
    this.post.cooked = `<aside class=\"quote no-group quote-post-not-found\" data-username=\"unknown\" data-post=\"1\" data-topic=\"123456\">\n<blockquote>\n<p>abcd</p>\n</blockquote>\n</aside>\n<p>Testing the issue</p>`;

    await renderComponent(this.post);

    assert
      .dom("aside.quote .title")
      .hasText("unknown")
      .doesNotHaveAttribute("data-has-quote-controls")
      .doesNotHaveAttribute("data-can-toggle-quote")
      .doesNotHaveAttribute("data-can-navigate-to-post");
    assert.dom(".quote-controls").doesNotExist();
    assert.dom("blockquote").hasText("abcd");
  });

  test("localizes internal onebox cards using localized_oneboxes", async function (assert) {
    this.post.cooked = `<aside class="quote" data-post="2" data-topic="55">
      <div class="title">
        <div class="quote-controls"></div>
        <div class="quote-title__text-content"><a href="/t/sun/55/2">Original Title</a></div>
      </div>
      <blockquote>Original preview</blockquote>
    </aside>`;
    this.post.localized_oneboxes = [
      {
        topic_id: 55,
        post_number: 2,
        title: "孫子の兵法",
        excerpt: "戦わずして勝つ",
      },
    ];

    await renderComponent(this.post);

    assert
      .dom("aside.quote .title")
      .includesText("孫子の兵法")
      .doesNotIncludeText("Original Title");
    assert.dom("aside.quote blockquote").includesText("戦わずして勝つ");
  });

  test("swaps only the title when no excerpt is provided", async function (assert) {
    this.post.cooked = `<aside class="quote" data-post="1" data-topic="55">
      <div class="title">
        <div class="quote-controls"></div>
        <div class="quote-title__text-content"><a href="/t/sun/55/1">Original Title</a></div>
      </div>
      <blockquote>Original preview</blockquote>
    </aside>`;
    this.post.localized_oneboxes = [
      { topic_id: 55, post_number: 1, title: "孫子の兵法" },
    ];

    await renderComponent(this.post);

    assert.dom("aside.quote .title").includesText("孫子の兵法");
    assert.dom("aside.quote blockquote").includesText("Original preview");
  });

  test("leaves same-topic inline quotes (with data-username) untouched", async function (assert) {
    this.post.cooked = `<aside class="quote" data-username="sun" data-post="2" data-topic="55">
      <div class="title"><div class="quote-controls"></div>sun:</div>
      <blockquote>Original preview</blockquote>
    </aside>`;
    this.post.localized_oneboxes = [
      {
        topic_id: 55,
        post_number: 2,
        title: "孫子の兵法",
        excerpt: "戦わずして勝つ",
      },
    ];

    await renderComponent(this.post);

    assert
      .dom("aside.quote blockquote")
      .includesText("Original preview")
      .doesNotIncludeText("戦わずして勝つ");
  });

  test("it keeps the opened state of the `details` tag between renders", async function (assert) {
    this.post.cooked = `<details><summary>Quote Summary</summary><p>Quote Content</p></details>`;

    await renderComponent(this.post);

    assert
      .dom("details")
      .exists()
      .doesNotHaveAttribute("open", "the details tag is closed by default");

    await click("details > summary");
    assert
      .dom("details")
      .hasAttribute(
        "open",
        "",
        "the details tag is opened after clicking the summary"
      );

    this.post.cooked += '<p class="new-content">New Content</p>';
    await settled();
    assert
      .dom("p.new-content")
      .exists()
      .hasText("New Content", "ensure the cooked content was updated");
    assert
      .dom("details")
      .exists()
      .hasAttribute(
        "open",
        "",
        "the details tag remains opened after re-rendering"
      );

    await click("details > summary");
    assert
      .dom("details")
      .doesNotHaveAttribute(
        "open",
        "the details tag is closed after clicking the summary again"
      );

    this.post.cooked += '<p class="another-content">Another Content</p>';
    await settled();

    assert
      .dom("p.another-content")
      .exists()
      .hasText(
        "Another Content",
        "ensure the cooked content was updated again"
      );
    assert
      .dom("details")
      .exists()
      .doesNotHaveAttribute(
        "open",
        "the details tag remains closed after re-rendering"
      );
  });
});
