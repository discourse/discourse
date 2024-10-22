import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

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

    assert.ok(exists(".reviewable-item"), "has a list of items");
    assert.ok(exists(user));
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

    assert.ok(visible(".reject-reason-reviewable-modal"));
    assert.ok(
      query(
        ".reject-reason-reviewable-modal .d-modal__title"
      ).innerHTML.includes(I18n.t("review.reject_reason.title")),
      "it opens reject reason modal when user is rejected"
    );

    await click(".d-modal__footer .cancel");
    await reviewableActionDropdown.expand();
    await reviewableActionDropdown.selectRowByValue("reject_user_block");

    assert.ok(visible(".reject-reason-reviewable-modal"));
    assert.ok(
      query(
        ".reject-reason-reviewable-modal .d-modal__title"
      ).innerHTML.includes(I18n.t("review.reject_reason.title")),
      "it opens reject reason modal when user is rejected and blocked"
    );
  });

  test("Settings", async function (assert) {
    await visit("/review/settings");

    assert.ok(exists(".reviewable-score-type"), "has a list of bonuses");

    const field = selectKit(
      ".reviewable-score-type:nth-of-type(1) .field .combo-box"
    );
    await field.expand();
    await field.selectRowByValue("5");
    await click(".save-settings");

    assert.ok(exists(".reviewable-settings .saved"), "it saved");
  });

  test("Flag related", async function (assert) {
    await visit("/review");

    assert
      .dom(".reviewable-flagged-post .post-contents .username a[href]")
      .exists("it has a link to the user");

    assert.strictEqual(
      query(".reviewable-flagged-post .post-body").innerHTML.trim(),
      "<b>cooked content</b>"
    );

    assert.strictEqual(count(".reviewable-flagged-post .reviewable-score"), 2);
  });

  test("Flag related", async function (assert) {
    await visit("/review/1");

    assert.ok(exists(".reviewable-flagged-post"), "it shows the flagged post");
  });

  test("Clicking the buttons triggers actions", async function (assert) {
    await visit("/review");
    await click(`${user} .reviewable-action.approve`);
    assert.ok(!exists(user), "it removes the reviewable on success");
  });

  test("Editing a reviewable", async function (assert) {
    const topic = '.reviewable-item[data-reviewable-id="4321"]';

    await visit("/review");

    assert.ok(exists(`${topic} .reviewable-action.approve`));
    assert.ok(!exists(`${topic} .badge-category__name`));

    assert.strictEqual(
      query(`${topic} .discourse-tag:nth-of-type(1)`).innerText,
      "hello"
    );

    assert.strictEqual(
      query(`${topic} .discourse-tag:nth-of-type(2)`).innerText,
      "world"
    );

    assert.strictEqual(
      query(`${topic} .post-body`).innerText.trim(),
      "existing body"
    );

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

    assert.strictEqual(
      query(`${topic} .post-body`).innerText.trim(),
      "existing body",
      "cancelling does not update the value"
    );

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
    assert.equal(requests.length, 1);
    assert.equal(requests[0].queryParams.categoryId, "6");
    await tags.fillInFilter("monkey");
    await tags.selectRowByValue("monkey");

    await fillIn(".editable-field.payload-raw textarea", "new raw contents");
    await click(`${topic} .reviewable-action.save-edit`);

    assert.strictEqual(
      query(`${topic} .discourse-tag:nth-of-type(1)`).innerText,
      "hello"
    );
    assert.strictEqual(
      query(`${topic} .discourse-tag:nth-of-type(2)`).innerText,
      "world"
    );
    assert.strictEqual(
      query(`${topic} .discourse-tag:nth-of-type(3)`).innerText,
      "monkey"
    );

    assert.strictEqual(
      query(`${topic} .post-body`).innerText.trim(),
      "new raw contents"
    );
    assert.strictEqual(
      query(`${topic} .badge-category__name`).innerText.trim(),
      "support"
    );
  });

  test("Reviewables can become stale", async function (assert) {
    await visit("/review");

    const reviewable = query(`[data-reviewable-id="1234"]`);
    assert.notOk(reviewable.className.includes("reviewable-stale"));
    assert.strictEqual(
      count(`[data-reviewable-id="1234"] .status .pending`),
      1
    );
    assert.dom(".stale-help").doesNotExist();

    await publishToMessageBus(`/reviewable_counts/${loggedInUser().id}`, {
      review_count: 1,
      updates: {
        1234: { last_performing_username: "foo", status: 1 },
      },
    });

    assert.ok(reviewable.className.includes("reviewable-stale"));
    assert.strictEqual(count("[data-reviewable-id=1234] .status .approved"), 1);
    assert.strictEqual(count(".stale-help"), 1);
    assert.ok(query(".stale-help").innerText.includes("foo"));

    await visit("/");
    await visit("/review"); // reload review

    assert.strictEqual(count(".stale-help"), 0);
  });
});
