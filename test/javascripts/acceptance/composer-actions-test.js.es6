import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";
import { _clearSnapshots } from "select-kit/components/composer-actions";
import { toggleCheckDraftPopup } from "discourse/controllers/composer";

acceptance("Composer Actions", {
  loggedIn: true,
  settings: {
    enable_whispers: true
  },
  beforeEach() {
    _clearSnapshots();
  }
});

QUnit.test("replying to post", async assert => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(
    composerActions.rowByIndex(1).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_whisper");
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
  assert.equal(composerActions.rowByIndex(5).value(), undefined);
});

QUnit.test("replying to post - reply_as_private_message", async assert => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");

  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_private_message");

  assert.equal(find(".users-input .item:eq(0)").text(), "codinghorror");
  assert.ok(
    find(".d-editor-input")
      .val()
      .indexOf("Continuing the discussion") >= 0
  );
});

QUnit.test("replying to post - reply_to_topic", async assert => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await fillIn(
    ".d-editor-input",
    "test replying to topic when initially replied to post"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("reply_to_topic");

  assert.equal(
    find(".action-title .topic-link")
      .text()
      .trim(),
    "Internationalization / localization"
  );
  assert.equal(
    find(".action-title .topic-link").attr("href"),
    "/t/internationalization-localization/280"
  );
  assert.equal(
    find(".d-editor-input").val(),
    "test replying to topic when initially replied to post"
  );
});

QUnit.test("replying to post - toggle_whisper", async assert => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await fillIn(
    ".d-editor-input",
    "test replying as whisper to topic when initially not a whisper"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("toggle_whisper");

  assert.ok(find(".composer-fields .whisper .d-icon-eye-slash").length === 1);
});

QUnit.test("replying to post - reply_as_new_topic", async assert => {
  const composerActions = selectKit(".composer-actions");
  const categoryChooser = selectKit(".title-wrapper .category-chooser");
  const categoryChooserReplyArea = selectKit(".reply-area .category-chooser");
  const quote = "test replying as new topic when initially replied to post";

  await visit("/t/internationalization-localization/280");

  await click("#topic-title .d-icon-pencil");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(4);
  await click("#topic-title .submit-edit");

  await click("article#post_3 button.reply");
  await fillIn(".d-editor-input", quote);

  await composerActions.expand();
  await composerActions.selectRowByValue("reply_as_new_topic");

  assert.equal(categoryChooserReplyArea.header().name(), "faq");
  assert.equal(
    find(".action-title")
      .text()
      .trim(),
    I18n.t("topic.create_long")
  );
  assert.ok(
    find(".d-editor-input")
      .val()
      .includes(quote)
  );
});

QUnit.test("shared draft", async assert => {
  toggleCheckDraftPopup(true);

  const composerActions = selectKit(".composer-actions");

  await visit("/");
  await click("#create-topic");

  await fillIn("#reply-title", "This is the new text for the title");
  await fillIn(".d-editor-input", "This is the new text for the post");

  await composerActions.expand();
  await composerActions.selectRowByValue("shared_draft");

  assert.equal(
    find("#reply-control .btn-primary.create .d-button-label").text(),
    I18n.t("composer.create_shared_draft")
  );
  assert.ok(find("#reply-control.composing-shared-draft").length === 1);

  toggleCheckDraftPopup(false);
});

QUnit.test("hide component if no content", async assert => {
  const composerActions = selectKit(".composer-actions");

  await visit("/u/eviltrout/messages");
  await click(".new-private-message");

  assert.ok(composerActions.el().hasClass("is-hidden"));
});

QUnit.test("interactions", async assert => {
  const composerActions = selectKit(".composer-actions");
  const quote = "Life is like riding a bicycle.";

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await fillIn(".d-editor-input", quote);
  await composerActions.expand();
  await composerActions.selectRowByValue("reply_to_topic");

  assert.equal(
    find(".action-title")
      .text()
      .trim(),
    "Internationalization / localization"
  );
  assert.equal(find(".d-editor-input").val(), quote);

  await composerActions.expand();

  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(composerActions.rowByIndex(1).value(), "reply_to_post");
  assert.equal(
    composerActions.rowByIndex(2).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_whisper");
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
  assert.equal(composerActions.rows().length, 5);

  await composerActions.selectRowByValue("reply_to_post");
  await composerActions.expand();

  assert.ok(exists(find(".action-title img.avatar")));
  assert.equal(
    find(".action-title .user-link")
      .text()
      .trim(),
    "codinghorror"
  );
  assert.equal(find(".d-editor-input").val(), quote);
  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(
    composerActions.rowByIndex(1).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_whisper");
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
  assert.equal(composerActions.rows().length, 5);

  await composerActions.selectRowByValue("reply_as_new_topic");
  await composerActions.expand();

  assert.equal(
    find(".action-title")
      .text()
      .trim(),
    I18n.t("topic.create_long")
  );
  assert.ok(
    find(".d-editor-input")
      .val()
      .includes(quote)
  );
  assert.equal(composerActions.rowByIndex(0).value(), "reply_to_post");
  assert.equal(
    composerActions.rowByIndex(1).value(),
    "reply_as_private_message"
  );
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rowByIndex(3).value(), "shared_draft");
  assert.equal(composerActions.rows().length, 4);

  await composerActions.selectRowByValue("reply_as_private_message");
  await composerActions.expand();

  assert.equal(
    find(".action-title")
      .text()
      .trim(),
    I18n.t("topic.private_message")
  );
  assert.ok(
    find(".d-editor-input")
      .val()
      .indexOf("Continuing the discussion") === 0
  );
  assert.equal(composerActions.rowByIndex(0).value(), "reply_as_new_topic");
  assert.equal(composerActions.rowByIndex(1).value(), "reply_to_post");
  assert.equal(composerActions.rowByIndex(2).value(), "reply_to_topic");
  assert.equal(composerActions.rows().length, 3);
});

QUnit.test("replying to post - toggle_topic_bump", async assert => {
  const composerActions = selectKit(".composer-actions");

  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");

  assert.ok(
    find(".composer-fields .no-bump").length === 0,
    "no-bump text is not visible"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("toggle_topic_bump");

  assert.ok(
    find(".composer-fields .no-bump").length === 1,
    "no-bump icon is visible"
  );

  await composerActions.expand();
  await composerActions.selectRowByValue("toggle_topic_bump");

  assert.ok(
    find(".composer-fields .no-bump").length === 0,
    "no-bump icon is not visible"
  );
});

QUnit.test("replying to post as staff", async assert => {
  const composerActions = selectKit(".composer-actions");

  replaceCurrentUser({ staff: true, admin: false });
  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 5);
  assert.equal(composerActions.rowByIndex(4).value(), "toggle_topic_bump");
});

QUnit.test("replying to post as TL3 user", async assert => {
  const composerActions = selectKit(".composer-actions");

  replaceCurrentUser({ staff: false, admin: false, trust_level: 3 });
  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 3);
  Array.from(composerActions.rows()).forEach(row => {
    assert.notEqual(
      row.value,
      "toggle_topic_bump",
      "toggle button is not visible"
    );
  });
});

QUnit.test("replying to post as TL4 user", async assert => {
  const composerActions = selectKit(".composer-actions");

  replaceCurrentUser({ staff: false, admin: false, trust_level: 4 });
  await visit("/t/internationalization-localization/280");
  await click("article#post_3 button.reply");
  await composerActions.expand();

  assert.equal(composerActions.rows().length, 4);
  assert.equal(composerActions.rowByIndex(3).value(), "toggle_topic_bump");
});

QUnit.test(
  "replying to first post - reply_as_private_message",
  async assert => {
    const composerActions = selectKit(".composer-actions");

    await visit("/t/internationalization-localization/280");
    await click("article#post_1 button.reply");

    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_private_message");

    assert.equal(find(".users-input .item:eq(0)").text(), "uwe_keim");
    assert.ok(
      find(".d-editor-input")
        .val()
        .indexOf("Continuing the discussion") >= 0
    );
  }
);
