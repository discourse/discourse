import { acceptance } from "helpers/qunit-helpers";
acceptance("Topic move posts", { loggedIn: true });

QUnit.test("default", async assert => {
  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-multi-select .btn");
  await click("#post_11 .select-below");

  assert.equal(
    find(".selected-posts .move-to-topic")
      .text()
      .trim(),
    I18n.t("topic.move_to.action"),
    "it should show the move to button"
  );

  await click(".selected-posts .move-to-topic");

  assert.ok(
    find(".move-to-modal .title")
      .html()
      .includes(I18n.t("topic.move_to.title")),
    "it opens move to modal"
  );

  assert.ok(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.split_topic.radio_label")),
    "it shows an option to move to new topic"
  );

  assert.ok(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.merge_topic.radio_label")),
    "it shows an option to move to existing topic"
  );

  assert.ok(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.move_to_new_message.radio_label")),
    "it shows an option to move to new message"
  );
});

QUnit.test("moving all posts", async assert => {
  await visit("/t/internationalization-localization");
  await click(".toggle-admin-menu");
  await click(".topic-admin-multi-select .btn");
  await click(".select-all");
  await click(".selected-posts .move-to-topic");

  assert.ok(
    find(".move-to-modal .title")
      .html()
      .includes(I18n.t("topic.move_to.title")),
    "it opens move to modal"
  );

  assert.not(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.split_topic.radio_label")),
    "it does not show an option to move to new topic"
  );

  assert.ok(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.merge_topic.radio_label")),
    "it shows an option to move to existing topic"
  );

  assert.not(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.move_to_new_message.radio_label")),
    "it does not show an option to move to new message"
  );
});

QUnit.test("moving posts from personal message", async assert => {
  await visit("/t/pm-for-testing/12");
  await click(".toggle-admin-menu");
  await click(".topic-admin-multi-select .btn");
  await click("#post_1 .select-post");

  assert.equal(
    find(".selected-posts .move-to-topic")
      .text()
      .trim(),
    I18n.t("topic.move_to.action"),
    "it should show the move to button"
  );

  await click(".selected-posts .move-to-topic");

  assert.ok(
    find(".move-to-modal .title")
      .html()
      .includes(I18n.t("topic.move_to.title")),
    "it opens move to modal"
  );

  assert.ok(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.move_to_new_message.radio_label")),
    "it shows an option to move to new message"
  );

  assert.ok(
    find(".move-to-modal .radios")
      .html()
      .includes(I18n.t("topic.move_to_existing_message.radio_label")),
    "it shows an option to move to existing message"
  );
});
