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

  let draft;
  let reviews;
  needs.hooks.beforeEach(() => {
    reviews = [];
    draft = {
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

  test("creates and revokes a review link, then hands off to the private feedback list", async function (assert) {
    pretender.get("/blog-editor/publications/280.json", () =>
      response({ ...draft, review_feedback_count: 1 })
    );
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
        expires_at: "2099-01-08T00:00:00Z",
        url: "https://blog.example.com/blog/review?review_token=secret",
      };
      reviews = [review];
      return response({ review });
    });
    pretender.get("/blog-editor/publications/280/feedback.json", () =>
      response({
        feedback: [
          {
            id: 1,
            name: "Guest",
            email: "",
            message: "Tighten the introduction.",
            created_at: "2030-01-01T00:00:00Z",
            review: { id: 1, label: "Editorial round", post_version: 1 },
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
    await click(".blog-publication-panel__menu-trigger");
    await click(".blog-publication-panel__share-for-review");
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
      .form(".blog-reviews__create")
      .field("label")
      .hasValue("", "the label is cleared for the next link");
    assert
      .dom(".blog-reviews__copy")
      .exists(
        "an issued link stays available to copy instead of being shown once"
      );
    assert
      .dom(".blog-reviews__open")
      .hasAttribute(
        "href",
        "https://blog.example.com/blog/review?review_token=secret"
      );
    await click(".blog-reviews__revoke");
    assert.verifySteps([], "revocation requires confirmation");
    await click(".dialog-footer .btn-primary");
    assert.verifySteps(["revoked"], "the selected grant is revoked");
    assert
      .dom(".blog-reviews__copy")
      .doesNotExist("a revoked link is no longer offered for sharing");
    assert
      .dom('[data-review-id="1"]')
      .includesText(
        "Revoked",
        "the old review remains listed with its feedback"
      );
    await click(".blog-reviews__feedback-link");
    assert
      .dom(".blog-reviews")
      .doesNotExist("the modal stays focused on links and closes");
    assert
      .dom(".blog-publication-panel__feedback-message")
      .hasText("Tighten the introduction.", "feedback opens in the panel");
  });

  test("names links that publishing closed", async function (assert) {
    reviews = [
      {
        id: 4,
        label: "Before launch",
        post_version: 1,
        active: false,
        feedback_count: 0,
        expires_at: "2099-01-08T00:00:00Z",
        revoked_at: "2030-01-01T00:00:00Z",
        revoked_by_publish: true,
      },
    ];
    await visit(TOPIC_URL);
    await click(".blog-publication-panel__menu-trigger");
    await click(".blog-publication-panel__share-for-review");
    assert
      .dom('[data-review-id="4"] .blog-reviews__status')
      .hasText(
        "Closed when published",
        "publish closures are not shown as revokes"
      );
    assert
      .dom('[data-review-id="4"] .blog-reviews__revoke')
      .doesNotExist("a closed link cannot be revoked again");
  });

  test("asks before discarding unsaved publication settings", async function (assert) {
    await visit(TOPIC_URL);
    await click(".blog-publication-panel__settings-toggle");
    await formKit(".blog-publication-panel__form")
      .field("excerpt")
      .fillIn("Unsaved publication excerpt");
    await click(".blog-publication-panel__menu-trigger");
    await click(".blog-publication-panel__share-for-review");
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
