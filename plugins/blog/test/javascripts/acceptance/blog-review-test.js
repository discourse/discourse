import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Blog review reader", function (needs) {
  needs.settings({ blog_enabled: true });

  needs.hooks.beforeEach(() => {
    pretender.get("/blog/review.json", (request) =>
      response({
        title: "A frozen draft",
        cooked: "<p>The article selected for review.</p>",
        post_version: request.queryParams.review_token === "new-round" ? 2 : 1,
        expires_at: "2030-01-01T00:00:00Z",
      })
    );
  });

  test("accepts private feedback without an account or forum chrome", async function (assert) {
    pretender.post("/blog/review/feedback.json", (request) => {
      const values = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        values.get("review_token"),
        "reader-capability",
        "submission is scoped to the review capability"
      );
      assert.strictEqual(
        values.get("feedback[message]"),
        "Please clarify the introduction.",
        "the feedback is submitted"
      );
      assert.step("feedback");
      return response(204);
    });
    await visit("/blog/review?review_token=reader-capability");
    assert
      .dom(".blog-review h1")
      .hasText("A frozen draft", "the frozen title is rendered");
    assert
      .dom(".blog-review__article")
      .hasText(
        "The article selected for review.",
        "the frozen body is rendered"
      );
    assert
      .dom(".d-header")
      .doesNotExist("reviewers do not see the forum header");
    assert
      .dom(".sidebar-wrapper")
      .doesNotExist("reviewers do not see the forum sidebar");
    await formKit(".blog-review form")
      .field("message")
      .fillIn("Please clarify the introduction.");
    await formKit(".blog-review form").submit();
    assert.verifySteps(["feedback"], "feedback is submitted once");
    assert
      .dom(".blog-review__feedback")
      .includesText("saved privately", "the reviewer gets confirmation");
    assert
      .dom(".blog-review form")
      .doesNotExist("the submitted form is replaced by confirmation");
  });

  test("clears the reader when access expires before submission", async function (assert) {
    pretender.post("/blog/review/feedback.json", () =>
      response(404, { errors: ["Unavailable"] })
    );
    await visit("/blog/review?review_token=reader-capability");
    await formKit(".blog-review form")
      .field("message")
      .fillIn("A late response");
    await formKit(".blog-review form").submit();
    assert
      .dom(".blog-review__article")
      .doesNotExist("the stale article is removed after access is denied");
    assert
      .dom(".blog-review")
      .includesText(
        "no longer available",
        "expiry is explained without offering submission again"
      );
  });

  test("shows unavailable links without a feedback form", async function (assert) {
    pretender.get("/blog/review.json", () =>
      response(404, { errors: ["Unavailable"] })
    );
    await visit("/blog/review?review_token=missing");
    assert
      .dom(".blog-review form")
      .doesNotExist("unavailable reviews cannot accept feedback");
    assert
      .dom(".alert-error")
      .includesText(
        "Ask the editor",
        "the recipient can request a replacement"
      );
  });
});
