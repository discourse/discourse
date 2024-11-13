import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Topic move posts", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/t/280/move-posts", () => {
      return helper.response(404, {
        errors: ["Invalid title"],
      });
    });
  });

  test("default", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_11 .select-below");

    assert
      .dom(".selected-posts .move-to-topic")
      .hasText(
        I18n.t("topic.move_to.action"),
        "it should show the move to button"
      );

    await click(".selected-posts .move-to-topic");

    assert
      .dom(".choose-topic-modal .d-modal__title")
      .includesHtml(I18n.t("topic.move_to.title"), "opens move to modal");

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.split_topic.radio_label"),
        "shows an option to move to new topic"
      );

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.merge_topic.radio_label"),
        "shows an option to move to existing topic"
      );

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.move_to_new_message.radio_label"),
        "shows an option to move to new message"
      );
  });

  test("display error when new topic has invalid title", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_11 .select-below");
    await click(".selected-posts .move-to-topic");
    await fillIn(".choose-topic-modal #split-topic-name", "Existing topic");
    await click(".choose-topic-modal .d-modal__footer .btn-primary");
    assert.dom("#modal-alert").hasText(I18n.t("topic.move_to.error"));
  });

  test("moving all posts", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click(".select-all");
    await click(".selected-posts .move-to-topic");

    assert
      .dom(".choose-topic-modal .d-modal__title")
      .includesHtml(I18n.t("topic.move_to.title"), "opens move to modal");

    assert
      .dom(".choose-topic-modal .radios")
      .doesNotIncludeHtml(
        I18n.t("topic.split_topic.radio_label"),
        "does not show an option to move to new topic"
      );

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.merge_topic.radio_label"),
        "shows an option to move to existing topic"
      );

    assert
      .dom(".choose-topic-modal .radios")
      .doesNotIncludeHtml(
        I18n.t("topic.move_to_new_message.radio_label"),
        "does not show an option to move to new message"
      );
  });

  test("moving posts to existing topic", async function (assert) {
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    await click(".selected-posts .move-to-topic");

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.merge_topic.radio_label"),
        "shows an option to move to an existing topic"
      );

    await click(".choose-topic-modal .radios #move-to-existing-topic");

    await fillIn(".choose-topic-modal #choose-topic-title", "Topic");

    assert
      .dom(".choose-topic-modal .checkbox-label")
      .doesNotExist(
        "there is no chronological order checkbox when no topic is selected"
      );

    await click(".choose-topic-list .existing-topic:first-child input");

    assert
      .dom(".choose-topic-modal .checkbox-label")
      .includesHtml(
        I18n.t("topic.merge_topic.chronological_order"),
        "shows a checkbox to merge posts in chronological order"
      );
  });

  test("moving posts from personal message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    assert
      .dom(".selected-posts .move-to-topic")
      .hasText(
        I18n.t("topic.move_to.action"),
        "it should show the move to button"
      );

    await click(".selected-posts .move-to-topic");

    assert
      .dom(".choose-topic-modal .d-modal__title")
      .includesHtml(I18n.t("topic.move_to.title"), "opens move to modal");

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.move_to_new_message.radio_label"),
        "shows an option to move to new message"
      );

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.move_to_existing_message.radio_label"),
        "shows an option to move to existing message"
      );
  });

  test("group moderator moving posts", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_2 .select-below");

    assert
      .dom(".selected-posts .move-to-topic")
      .hasText(
        I18n.t("topic.move_to.action"),
        "it should show the move to button"
      );

    await click(".selected-posts .move-to-topic");

    assert
      .dom(".choose-topic-modal .d-modal__title")
      .includesHtml(I18n.t("topic.move_to.title"), "opens move to modal");
  });

  test("moving posts from personal message to existing message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");

    await click(".selected-posts .move-to-topic");

    assert
      .dom(".choose-topic-modal .radios")
      .includesHtml(
        I18n.t("topic.move_to_existing_message.radio_label"),
        "shows an option to move to an existing message"
      );

    await click(".choose-topic-modal .radios #move-to-existing-message");

    await fillIn(".choose-topic-modal #choose-message-title", "Topic");

    assert
      .dom(".choose-topic-modal .checkbox-label")
      .doesNotExist(
        "there is no chronological order checkbox when no message is selected"
      );

    await click(".choose-topic-modal .existing-message:first-of-type input");

    assert
      .dom(".choose-topic-modal .checkbox-label")
      .includesHtml(
        I18n.t("topic.merge_topic.chronological_order"),
        "shows a checkbox to merge posts in chronological order"
      );
  });
});
