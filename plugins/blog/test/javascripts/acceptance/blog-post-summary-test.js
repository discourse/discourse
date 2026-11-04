import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import EmbedMode from "discourse/lib/embed-mode";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Blog article summary", function (needs) {
  needs.settings({ blog_enabled: true });
  let article;
  let originalEmbedMode;

  needs.hooks.beforeEach(() => {
    originalEmbedMode = EmbedMode.enabled;
    article = {
      url: "https://blog.example.com/workflow",
      excerpt: "A useful editorial summary.",
      blog_name: "The blog",
    };
  });
  needs.hooks.afterEach(() => {
    EmbedMode.enabled = originalEmbedMode;
  });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => {
      const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
      topic.post_stream.posts[0].blog_article = article;
      topic.post_stream.posts[0].cooked =
        "<p>The complete article is available here.</p><pre><code>bin/rails server</code></pre>";
      return helper.response(topic);
    });
  });

  test("summarizes the first post and expands the native cooked content inline", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert
      .dom("#post_1 .blog-post-summary__excerpt")
      .hasText(article.excerpt, "the editorial excerpt is displayed");
    assert
      .dom("#post_1 .blog-post-summary a")
      .hasAttribute("href", article.url, "the summary links to the blog");
    assert
      .dom("#post_1 .cooked")
      .doesNotExist("the full article is initially collapsed");
    assert
      .dom("#post_2 .cooked")
      .exists("replies still use the normal renderer");
    assert
      .dom("#post_1 .blog-post-summary button")
      .hasAttribute(
        "aria-expanded",
        "false",
        "the collapsed state is accessible"
      );

    await click("#post_1 .blog-post-summary button");
    assert
      .dom("#post_1 .cooked p")
      .hasText(
        "The complete article is available here.",
        "expansion restores the full article"
      );
    assert
      .dom("#post_1 .cooked pre code")
      .hasText("bin/rails server", "code markup is preserved");
    assert
      .dom("#post_1 .blog-post-summary button")
      .hasAttribute(
        "aria-expanded",
        "true",
        "the expanded state is accessible"
      );

    await click("#post_1 .blog-post-summary button");
    assert
      .dom("#post_1 .cooked")
      .doesNotExist("the article can be collapsed again");
  });

  test("leaves posts without published article metadata alone", async function (assert) {
    article = null;
    await visit("/t/internationalization-localization/280");
    assert
      .dom(".blog-post-summary")
      .doesNotExist("ordinary posts have no summary");
    assert.dom("#post_1 .cooked").exists("the full post remains visible");
  });

  test("keeps article text visible when arriving with search context", async function (assert) {
    await visit("/t/internationalization-localization/280?search=complete");
    assert
      .dom(".blog-post-summary")
      .doesNotExist("search results do not hide their matching text");
    assert.dom("#post_1 .cooked").exists("the complete article is rendered");
  });

  test("does not change the embedded discussion renderer", async function (assert) {
    EmbedMode.enabled = true;
    await visit("/t/internationalization-localization/280");
    assert
      .dom(".blog-post-summary")
      .doesNotExist("embedded discussions keep the existing behavior");
  });
});
