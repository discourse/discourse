import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Topic move posts", function (needs) {
  needs.user();

  test("default", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_11 .select-below");

    assert.strictEqual(
      queryAll(".selected-posts .move-to-topic").text().trim(),
      I18n.t("topic.move_to.action"),
      "it should show the move to button"
    );

    await click(".selected-posts .move-to-topic");

    assert.ok(
      queryAll(".choose-topic-modal .title")
        .html()
        .includes(I18n.t("topic.move_to.title")),
      "it opens move to modal"
    );

    assert.ok(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.split_topic.radio_label")),
      "it shows an option to move to new topic"
    );

    assert.ok(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.merge_topic.radio_label")),
      "it shows an option to move to existing topic"
    );

    assert.ok(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.move_to_new_message.radio_label")),
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
      queryAll(".choose-topic-modal .title")
        .html()
        .includes(I18n.t("topic.move_to.title")),
      "it opens move to modal"
    );

    assert.notOk(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.split_topic.radio_label")),
      "it does not show an option to move to new topic"
    );

    assert.ok(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.merge_topic.radio_label")),
      "it shows an option to move to existing topic"
    );

    assert.notOk(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.move_to_new_message.radio_label")),
      "it does not show an option to move to new message"
    );
  });

  test("moving posts from personal message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    assert.strictEqual(
      queryAll(".selected-posts .move-to-topic").text().trim(),
      I18n.t("topic.move_to.action"),
      "it should show the move to button"
    );

    await click(".selected-posts .move-to-topic");

    assert.ok(
      queryAll(".choose-topic-modal .title")
        .html()
        .includes(I18n.t("topic.move_to.title")),
      "it opens move to modal"
    );

    assert.ok(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.move_to_new_message.radio_label")),
      "it shows an option to move to new message"
    );

    assert.ok(
      queryAll(".choose-topic-modal .radios")
        .html()
        .includes(I18n.t("topic.move_to_existing_message.radio_label")),
      "it shows an option to move to existing message"
    );
  });

  test("group moderator moving posts", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_2 .select-below");

    assert.strictEqual(
      queryAll(".selected-posts .move-to-topic").text().trim(),
      I18n.t("topic.move_to.action"),
      "it should show the move to button"
    );

    await click(".selected-posts .move-to-topic");

    assert.ok(
      queryAll(".choose-topic-modal .title")
        .html()
        .includes(I18n.t("topic.move_to.title")),
      "it opens move to modal"
    );
  });
});
