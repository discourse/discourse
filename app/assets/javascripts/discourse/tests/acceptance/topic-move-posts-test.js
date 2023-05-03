import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";
import searchFixtures from "discourse/tests/fixtures/search-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

let hasCalledMovedPostsEndpoint;

acceptance("Topic move posts", function (needs) {
  needs.user();

  needs.hooks.beforeEach(() => {
    hasCalledMovedPostsEndpoint = false;
  });

  needs.pretender((server, helper) => {
    server.get("/search/query", (request) => {
      const result = cloneJSON(searchFixtures["search/query"]);

      if (request.queryParams.term.includes("Newer topic")) {
        result.topics[0].last_posted_at = "2020-12-22T05:50:15.898Z";
      } else if (request.queryParams.term.includes("Older topic")) {
        result.topics[0].last_posted_at = "2012-02-07T17:46:57.262Z";
      }

      return helper.response(result);
    });

    const movePostsHandler = () => {
      hasCalledMovedPostsEndpoint = true;
      return helper.response({ success: true });
    };

    server.post("/t/12/move-posts", movePostsHandler);
    server.post("/t/280/move-posts", movePostsHandler);
  });

  test("default", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_11 .select-below");

    assert.strictEqual(
      query(".selected-posts .move-to-topic").innerText.trim(),
      I18n.t("topic.move_to.action"),
      "it should show the move to button"
    );

    await click(".selected-posts .move-to-topic");

    assert.ok(
      query(".choose-topic-modal .title").innerHTML.includes(
        I18n.t("topic.move_to.title")
      ),
      "it opens move to modal"
    );

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.split_topic.radio_label")
      ),
      "it shows an option to move to new topic"
    );

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.merge_topic.radio_label")
      ),
      "it shows an option to move to existing topic"
    );

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.move_to_new_message.radio_label")
      ),
      "it shows an option to move to new message"
    );
  });

  test("moving all posts", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click(".select-all");
    await click(".selected-posts .move-to-topic");

    assert.ok(
      query(".choose-topic-modal .title").innerHTML.includes(
        I18n.t("topic.move_to.title")
      ),
      "it opens move to modal"
    );

    assert.notOk(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.split_topic.radio_label")
      ),
      "it does not show an option to move to new topic"
    );

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.merge_topic.radio_label")
      ),
      "it shows an option to move to existing topic"
    );

    assert.notOk(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.move_to_new_message.radio_label")
      ),
      "it does not show an option to move to new message"
    );
  });

  test("moving earlier posts to existing topic", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    await click(".selected-posts .move-to-topic");

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.merge_topic.radio_label")
      ),
      "it shows an option to move to an existing topic"
    );

    await click(".choose-topic-modal .radios #move-to-existing-topic");

    await fillIn(".choose-topic-modal #choose-topic-title", "Newer topic");

    await click(".choose-topic-list .existing-topic:first-child input");

    await click(".choose-topic-modal .modal-footer .btn");

    assert.ok(
      query(".merge-type-modal").innerHTML.includes(
        I18n.t("topic.merge_topic.merge_type.sequential")
      ),
      "it shows an option to move posts sequentially"
    );

    assert.ok(
      query(".merge-type-modal").innerHTML.includes(
        I18n.t("topic.merge_topic.merge_type.chronological")
      ),
      "it shows an option to move posts chronologically"
    );
  });

  test("moving posts to existing topic", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    await click(".selected-posts .move-to-topic");

    await click(".choose-topic-modal .radios #move-to-existing-topic");

    await fillIn(".choose-topic-modal #choose-topic-title", "Older topic");

    await click(".choose-topic-list .existing-topic:first-child input");

    await click(".choose-topic-modal .modal-footer .btn");

    assert.ok(
      hasCalledMovedPostsEndpoint,
      "it moves posts without showing the merge type modal"
    );
  });

  test("moving posts from personal message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    assert.strictEqual(
      query(".selected-posts .move-to-topic").innerText.trim(),
      I18n.t("topic.move_to.action"),
      "it should show the move to button"
    );

    await click(".selected-posts .move-to-topic");

    assert.ok(
      query(".choose-topic-modal .title").innerHTML.includes(
        I18n.t("topic.move_to.title")
      ),
      "it opens move to modal"
    );

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.move_to_new_message.radio_label")
      ),
      "it shows an option to move to new message"
    );

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.move_to_existing_message.radio_label")
      ),
      "it shows an option to move to existing message"
    );
  });

  test("group moderator moving posts", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_2 .select-below");

    assert.strictEqual(
      query(".selected-posts .move-to-topic").innerText.trim(),
      I18n.t("topic.move_to.action"),
      "it should show the move to button"
    );

    await click(".selected-posts .move-to-topic");

    assert.ok(
      query(".choose-topic-modal .title").innerHTML.includes(
        I18n.t("topic.move_to.title")
      ),
      "it opens move to modal"
    );
  });

  test("moving earlier posts from personal message to existing message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    await click(".selected-posts .move-to-topic");

    assert.ok(
      query(".choose-topic-modal .radios").innerHTML.includes(
        I18n.t("topic.move_to_existing_message.radio_label")
      ),
      "it shows an option to move to an existing message"
    );

    await click(".choose-topic-modal .radios #move-to-existing-message");

    await fillIn(".choose-topic-modal #choose-message-title", "Newer topic");

    await click(".choose-topic-modal .existing-message:first-of-type input");

    await click(".choose-topic-modal .modal-footer .btn");

    assert.ok(
      query(".merge-type-modal").innerHTML.includes(
        I18n.t("topic.move_to_existing_message.merge_type.sequential")
      ),
      "it shows an option to move posts sequentially"
    );

    assert.ok(
      query(".merge-type-modal").innerHTML.includes(
        I18n.t("topic.move_to_existing_message.merge_type.chronological")
      ),
      "it shows an option to move posts chronologically"
    );
  });

  test("moving posts from personal message to existing message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    await click(".selected-posts .move-to-topic");

    await click(".choose-topic-modal .radios #move-to-existing-message");

    await fillIn(".choose-topic-modal #choose-message-title", "Older topic");

    await click(".choose-topic-modal .existing-message:first-of-type input");

    await click(".choose-topic-modal .modal-footer .btn");

    assert.ok(
      hasCalledMovedPostsEndpoint,
      "it moves posts without showing the merge type modal"
    );
  });
});
