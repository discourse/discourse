import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const TOPIC_URL = "/t/internationalization-localization/280";

acceptance("Blog review management", function (needs) {
  needs.user({ admin: true });
  needs.settings({ blog_enabled: true });

  let reviews;
  needs.hooks.beforeEach(() => {
    reviews = [];
    const draft = {
      id: 280,
      role: "draft",
      status: "draft",
      source_topic_id: 280,
      source_url: TOPIC_URL,
      title: "Private article",
      draft: true,
      published: false,
      live: false,
      can_publish: true,
      changes: [],
      path: "/private-article",
      url: "https://blog.example.com/private-article",
      excerpt: "",
      featured: false,
    };
    pretender.get("/t/280.json", () => {
      const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
      topic.blog_publication = draft;
      return response(topic);
    });
    pretender.get("/blog-editor/publications/280/reviews.json", () =>
      response({ reviews, more: false })
    );
  });

  test("creates, reads private feedback, and revokes a review link separately from publication", async function (assert) {
    pretender.post("/blog-editor/publications/280/reviews.json", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("label"),
        "Editorial round",
        "the optional label is saved"
      );
      const review = {
        id: 1,
        label: "Editorial round",
        post_version: 1,
        active: true,
        feedback_count: 1,
        url: "https://blog.example.com/blog/review?review_token=secret",
      };
      reviews = [review];
      return response({ review });
    });
    pretender.get("/blog-editor/publications/280/reviews/1/feedback.json", () =>
      response({
        feedback: [
          {
            id: 1,
            name: "Guest",
            email: "",
            message: "<script>not executable</script>",
            created_at: "2030-01-01T00:00:00Z",
          },
        ],
        more: false,
      })
    );
    pretender.delete("/blog-editor/publications/280/reviews/1.json", () => {
      reviews = [
        {
          ...reviews[0],
          active: false,
          url: null,
          revoked_at: "2030-01-01T00:00:00Z",
        },
      ];
      assert.step("revoked");
      return response(204);
    });
    await visit(TOPIC_URL);
    await click(".blog-publication-panel__reviews");
    assert
      .dom(".blog-reviews")
      .includesText(
        "Anyone with the link",
        "the sharing boundary is explained before creation"
      );
    await formKit(".blog-reviews__create")
      .field("label")
      .fillIn("Editorial round");
    await formKit(".blog-reviews__create").submit();
    assert
      .dom(".blog-reviews__link-url")
      .hasValue(
        "https://blog.example.com/blog/review?review_token=secret",
        "an issued link stays readable instead of being shown once"
      );
    assert
      .dom(".blog-reviews__open")
      .hasAttribute(
        "href",
        "https://blog.example.com/blog/review?review_token=secret"
      );
    await click(".blog-reviews__feedback-toggle");
    assert
      .dom(".blog-reviews__feedback p")
      .hasText(
        "<script>not executable</script>",
        "untrusted feedback is escaped"
      );
    assert
      .dom(".blog-reviews__feedback script")
      .doesNotExist("feedback never becomes executable HTML");
    await click(".blog-reviews__revoke");
    assert.verifySteps([], "revocation requires confirmation");
    await click(".dialog-footer .btn-primary");
    assert.verifySteps(["revoked"], "the selected grant is revoked");
    assert
      .dom(".blog-reviews__link")
      .doesNotExist("a revoked link is no longer offered for sharing");
    assert
      .dom('[data-review-id="1"]')
      .includesText(
        "Expired or revoked",
        "the old review remains available for private feedback"
      );
  });

  test("asks before discarding unsaved publication settings", async function (assert) {
    await visit(TOPIC_URL);
    await click(".blog-publication-panel__settings-toggle");
    await formKit(".blog-publication-panel__form")
      .field("excerpt")
      .fillIn("Unsaved publication excerpt");
    await click(".blog-publication-panel__reviews");
    assert
      .dom(".dialog-body")
      .includesText(
        "Discard unsaved publication settings",
        "sharing does not silently discard metadata edits"
      );
    assert
      .dom(".blog-reviews")
      .doesNotExist("review management waits for confirmation");
    await click(".dialog-footer .btn-primary");
    assert
      .dom(".blog-reviews")
      .exists("confirmation opens the saved-article sharing workflow");
  });
});
