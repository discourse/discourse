import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  loggedInUser,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Review", function (needs) {
  needs.user();

  let requests = [];

  needs.pretender((server, helper) => {
    server.get("/tags/filter/search", (request) => {
      requests.push(request);
      return helper.response({
        results: [
          { id: "monkey", name: "monkey", count: 1 },
          { id: "not-monkey", name: "not-monkey", count: 1 },
          { id: "happy-monkey", name: "happy-monkey", count: 1 },
        ],
      });
    });
  });

  const user = '.reviewable-item[data-reviewable-id="1234"]';

  test("It returns a list of reviewable items", async function (assert) {
    await visit("/review");

    assert.dom(".reviewable-item").exists("has a list of items");
    assert.dom(user).exists();
    assert
      .dom(`${user}.reviewable-user`)
      .exists("applies a class for the type");
    assert
      .dom(`${user} .reviewable-action.approve`)
      .exists("creates a button for approve");
    assert
      .dom(`${user} .reviewable-action.reject`)
      .exists("creates a button for reject");
  });

  test("Grouped by topic", async function (assert) {
    await visit("/review/topics");
    assert
      .dom(".reviewable-topic")
      .exists("it has a list of reviewable topics");
  });

  test("Reject user", async function (assert) {
    let reviewableActionDropdown = selectKit(
      `${user} .reviewable-action-dropdown`
    );

    await visit("/review");
    await reviewableActionDropdown.expand();
    await reviewableActionDropdown.selectRowByValue("reject_user_delete");

    assert.dom(".reject-reason-reviewable-modal").exists();
    assert
      .dom(".reject-reason-reviewable-modal .d-modal__title")
      .includesHtml(
        i18n("review.reject_reason.title"),
        "opens reject reason modal when user is rejected"
      );

    await click(".d-modal__footer .cancel");
    await reviewableActionDropdown.expand();
    await reviewableActionDropdown.selectRowByValue("reject_user_block");

    assert.dom(".reject-reason-reviewable-modal").exists();
    assert
      .dom(".reject-reason-reviewable-modal .d-modal__title")
      .includesHtml(
        i18n("review.reject_reason.title"),
        "opens reject reason modal when user is rejected and blocked"
      );
  });

  test("Settings", async function (assert) {
    await visit("/review/settings");

    assert.dom(".reviewable-score-type").exists("has a list of bonuses");

    const field = selectKit(
      ".reviewable-score-type:nth-of-type(1) .field .combo-box"
    );
    await field.expand();
    await field.selectRowByValue("5");
    await click(".save-settings");

    assert.dom(".reviewable-settings .saved").exists("it saved");
  });

  test("Flag related", async function (assert) {
    await visit("/review");

    assert
      .dom(".reviewable-flagged-post .post-contents .username a[href]")
      .exists("it has a link to the user");

    assert
      .dom(".reviewable-flagged-post .post-body")
      .hasHtml("<b>cooked content</b>");

    assert
      .dom(".reviewable-flagged-post .reviewable-score")
      .exists({ count: 2 });
  });

  test("Flag related", async function (assert) {
    await visit("/review/1");

    assert.dom(".reviewable-flagged-post").exists("shows the flagged post");
  });

  test("Clicking the buttons triggers actions", async function (assert) {
    await visit("/review");
    await click(`${user} .reviewable-action.approve`);
    assert.dom(user).doesNotExist("removes the reviewable on success");
  });

  test("Editing a reviewable", async function (assert) {
    const topic = '.reviewable-item[data-reviewable-id="4321"]';

    await visit("/review");

    assert.dom(`${topic} .reviewable-action.approve`).exists();
    assert.dom(`${topic} .badge-category__name`).doesNotExist();

    assert.dom(`${topic} .discourse-tag:nth-of-type(1)`).hasText("hello");
    assert.dom(`${topic} .discourse-tag:nth-of-type(2)`).hasText("world");

    assert.dom(`${topic} .post-body`).hasText("existing body");

    await click(`${topic} .reviewable-action.edit`);
    await click(`${topic} .reviewable-action.save-edit`);

    assert
      .dom(`${topic} .reviewable-action.approve`)
      .exists("saving without changes is a cancel");

    await click(`${topic} .reviewable-action.edit`);

    assert
      .dom(`${topic} .reviewable-action.approve`)
      .doesNotExist("when editing actions are disabled");

    await fillIn(".editable-field.payload-raw textarea", "new raw contents");
    await click(`${topic} .reviewable-action.cancel-edit`);

    assert
      .dom(`${topic} .post-body`)
      .hasText("existing body", "cancelling does not update the value");

    await click(`${topic} .reviewable-action.edit`);
    let category = selectKit(`${topic} .category-id .select-kit`);

    await category.expand();
    await category.selectRowByValue("6");

    assert.strictEqual(
      category.header().name(),
      "support",
      "displays the right header"
    );

    let tags = selectKit(`${topic} .payload-tags .mini-tag-chooser`);
    requests = [];
    await tags.expand();
    assert.strictEqual(requests.length, 1);
    assert.strictEqual(requests[0].queryParams.categoryId, "6");
    await tags.fillInFilter("monkey");
    await tags.selectRowByValue("monkey");

    await fillIn(".editable-field.payload-raw textarea", "new raw contents");
    await click(`${topic} .reviewable-action.save-edit`);

    assert.dom(`${topic} .discourse-tag:nth-of-type(1)`).hasText("hello");
    assert.dom(`${topic} .discourse-tag:nth-of-type(2)`).hasText("world");
    assert.dom(`${topic} .discourse-tag:nth-of-type(3)`).hasText("monkey");

    assert.dom(`${topic} .post-body`).hasText("new raw contents");
    assert.dom(`${topic} .badge-category__name`).hasText("support");
  });

  test("Reviewables can become stale", async function (assert) {
    await visit("/review");

    assert
      .dom("[data-reviewable-id='1234']")
      .doesNotHaveClass("reviewable-stale");
    assert.dom("[data-reviewable-id='1234'] .status .pending").exists();
    assert.dom(".stale-help").doesNotExist();

    await publishToMessageBus(`/reviewable_counts/${loggedInUser().id}`, {
      review_count: 1,
      updates: {
        1234: { last_performing_username: "foo", status: 1 },
      },
    });

    assert.dom("[data-reviewable-id='1234']").hasClass("reviewable-stale");
    assert.dom("[data-reviewable-id='1234'] .status .approved").exists();
    assert.dom(".stale-help").exists();
    assert.dom(".stale-help").includesText("foo");

    await visit("/");
    await visit("/review"); // reload review

    assert.dom(".stale-help").doesNotExist();
  });
});
