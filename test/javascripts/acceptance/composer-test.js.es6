import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Composer", {
  loggedIn: true,
  settings: {
    enable_whispers: true
  }
});

QUnit.test("Tests the Composer controls", async assert => {
  await visit("/");
  assert.ok(exists("#create-topic"), "the create button is visible");

  await click("#create-topic");
  assert.ok(exists(".d-editor-input"), "the composer input is visible");
  assert.ok(
    exists(".title-input .popup-tip.bad.hide"),
    "title errors are hidden by default"
  );
  assert.ok(
    exists(".d-editor-textarea-wrapper .popup-tip.bad.hide"),
    "body errors are hidden by default"
  );

  await click("a.toggle-preview");
  assert.ok(
    !exists(".d-editor-preview:visible"),
    "clicking the toggle hides the preview"
  );

  await click("a.toggle-preview");
  assert.ok(
    exists(".d-editor-preview:visible"),
    "clicking the toggle shows the preview again"
  );

  await click("#reply-control button.create");
  assert.ok(
    !exists(".title-input .popup-tip.bad.hide"),
    "it shows the empty title error"
  );
  assert.ok(
    !exists(".d-editor-wrapper .popup-tip.bad.hide"),
    "it shows the empty body error"
  );

  await fillIn("#reply-title", "this is my new topic title");
  assert.ok(exists(".title-input .popup-tip.good"), "the title is now good");

  await fillIn(".d-editor-input", "this is the *content* of a post");
  assert.equal(
    find(".d-editor-preview")
      .html()
      .trim(),
    "<p>this is the <em>content</em> of a post</p>",
    "it previews content"
  );
  assert.ok(
    exists(".d-editor-textarea-wrapper .popup-tip.good"),
    "the body is now good"
  );

  const textarea = find("#reply-control .d-editor-input")[0];
  textarea.selectionStart = textarea.value.length;
  textarea.selectionEnd = textarea.value.length;

  // Testing keyboard events is tough!
  const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
  const event = document.createEvent("Event");
  event.initEvent("keydown", true, true);
  event[mac ? "metaKey" : "ctrlKey"] = true;
  event.keyCode = 66;

  Ember.run(() => textarea.dispatchEvent(event));

  const example = I18n.t(`composer.bold_text`);
  assert.equal(
    find("#reply-control .d-editor-input")
      .val()
      .trim(),
    `this is the *content* of a post**${example}**`,
    "it supports keyboard shortcuts"
  );

  await click("#reply-control a.cancel");
  assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");

  await click(".modal-footer a:eq(1)");
  assert.ok(!exists(".bootbox.modal"), "the confirmation can be cancelled");
});

QUnit.test("Create a topic with server side errors", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn("#reply-title", "this title triggers an error");
  await fillIn(".d-editor-input", "this is the *content* of a post");
  await click("#reply-control button.create");
  assert.ok(exists(".bootbox.modal"), "it pops up an error message");
  await click(".bootbox.modal a.btn-primary");
  assert.ok(!exists(".bootbox.modal"), "it dismisses the error");
  assert.ok(exists(".d-editor-input"), "the composer input is visible");
});

QUnit.test("Create a Topic", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn("#reply-title", "Internationalization Localization");
  await fillIn(".d-editor-input", "this is the *content* of a new topic post");
  await click("#reply-control button.create");
  assert.equal(
    currentURL(),
    "/t/internationalization-localization/280",
    "it transitions to the newly created topic URL"
  );
});

QUnit.test("Create an enqueued Topic", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn("#reply-title", "Internationalization Localization");
  await fillIn(".d-editor-input", "enqueue this content please");
  await click("#reply-control button.create");
  assert.ok(visible(".d-modal"), "it pops up a modal");
  assert.equal(currentURL(), "/", "it doesn't change routes");

  await click(".modal-footer button");
  assert.ok(invisible(".d-modal"), "the modal can be dismissed");
});

QUnit.test("Create a Reply", async assert => {
  await visit("/t/internationalization-localization/280");

  assert.ok(
    !exists("article[data-post-id=12345]"),
    "the post is not in the DOM"
  );

  await click("#topic-footer-buttons .btn.create");
  assert.ok(exists(".d-editor-input"), "the composer input is visible");
  assert.ok(!exists("#reply-title"), "there is no title since this is a reply");

  await fillIn(".d-editor-input", "this is the content of my reply");
  await click("#reply-control button.create");
  assert.equal(
    find(".cooked:last p").text(),
    "this is the content of my reply"
  );
});

QUnit.test("Posting on a different topic", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");
  await fillIn(".d-editor-input", "this is the content for a different topic");

  await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
  assert.equal(currentURL(), "/t/1-3-0beta9-no-rate-limit-popups/28830");
  await click("#reply-control button.create");
  assert.ok(visible(".reply-where-modal"), "it pops up a modal");

  await click(".btn-reply-here");
  assert.equal(
    find(".cooked:last p").text(),
    "this is the content for a different topic"
  );
});

QUnit.test("Create an enqueued Reply", async assert => {
  await visit("/t/internationalization-localization/280");

  await click("#topic-footer-buttons .btn.create");
  assert.ok(exists(".d-editor-input"), "the composer input is visible");
  assert.ok(!exists("#reply-title"), "there is no title since this is a reply");

  await fillIn(".d-editor-input", "enqueue this content please");
  await click("#reply-control button.create");
  assert.ok(
    find(".cooked:last p").text() !== "enqueue this content please",
    "it doesn't insert the post"
  );

  assert.ok(visible(".d-modal"), "it pops up a modal");

  await click(".modal-footer button");
  assert.ok(invisible(".d-modal"), "the modal can be dismissed");
});

QUnit.test("Edit the first post", async assert => {
  await visit("/t/internationalization-localization/280");

  assert.ok(
    !exists(".topic-post:eq(0) .post-info.edits"),
    "it has no edits icon at first"
  );

  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.edit");
  assert.equal(
    find(".d-editor-input")
      .val()
      .indexOf("Any plans to support"),
    0,
    "it populates the input with the post text"
  );

  await fillIn(".d-editor-input", "This is the new text for the post");
  await fillIn("#reply-title", "This is the new text for the title");
  await click("#reply-control button.create");
  assert.ok(!exists(".d-editor-input"), "it closes the composer");
  assert.ok(
    exists(".topic-post:eq(0) .post-info.edits"),
    "it has the edits icon"
  );
  assert.ok(
    find("#topic-title h1")
      .text()
      .indexOf("This is the new text for the title") !== -1,
    "it shows the new title"
  );
  assert.ok(
    find(".topic-post:eq(0) .cooked")
      .text()
      .indexOf("This is the new text for the post") !== -1,
    "it updates the post"
  );
});

QUnit.test("Composer can switch between edits", async assert => {
  await visit("/t/this-is-a-test-topic/9");

  await click(".topic-post:eq(0) button.edit");
  assert.equal(
    find(".d-editor-input")
      .val()
      .indexOf("This is the first post."),
    0,
    "it populates the input with the post text"
  );
  await click(".topic-post:eq(1) button.edit");
  assert.equal(
    find(".d-editor-input")
      .val()
      .indexOf("This is the second post."),
    0,
    "it populates the input with the post text"
  );
});

QUnit.test(
  "Composer with dirty edit can toggle to another edit",
  async assert => {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:eq(0) button.edit");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".topic-post:eq(1) button.edit");
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");

    await click(".modal-footer a:eq(0)");
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  }
);

QUnit.test("Composer can toggle between edit and reply", async assert => {
  await visit("/t/this-is-a-test-topic/9");

  await click(".topic-post:eq(0) button.edit");
  assert.equal(
    find(".d-editor-input")
      .val()
      .indexOf("This is the first post."),
    0,
    "it populates the input with the post text"
  );
  await click(".topic-post:eq(0) button.reply");
  assert.equal(find(".d-editor-input").val(), "", "it clears the input");
  await click(".topic-post:eq(0) button.edit");
  assert.equal(
    find(".d-editor-input")
      .val()
      .indexOf("This is the first post."),
    0,
    "it populates the input with the post text"
  );
});

QUnit.test("Composer can toggle whispers", async assert => {
  await visit("/t/this-is-a-test-topic/9");
  await click(".topic-post:eq(0) button.reply");

  await selectKit(".toolbar-popup-menu-options").expand();
  await selectKit(".toolbar-popup-menu-options").selectRowByValue(
    "toggleWhisper"
  );

  assert.ok(
    find(".composer-fields .whisper")
      .text()
      .indexOf(I18n.t("composer.whisper")) > 0,
    "it sets the post type to whisper"
  );

  await selectKit(".toolbar-popup-menu-options").expand();
  await selectKit(".toolbar-popup-menu-options").selectRowByValue(
    "toggleWhisper"
  );

  assert.ok(
    find(".composer-fields .whisper")
      .text()
      .indexOf(I18n.t("composer.whisper")) <= 0,
    "it removes the whisper mode"
  );
});

QUnit.test(
  "Composer can toggle between reply and createTopic",
  async assert => {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:eq(0) button.reply");

    await selectKit(".toolbar-popup-menu-options").expand();
    await selectKit(".toolbar-popup-menu-options").selectRowByValue(
      "toggleWhisper"
    );

    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.whisper")) > 0,
      "it sets the post type to whisper"
    );

    await visit("/");
    assert.ok(exists("#create-topic"), "the create topic button is visible");

    await click("#create-topic");
    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.whisper")) === -1,
      "it should reset the state of the composer's model"
    );

    await selectKit(".toolbar-popup-menu-options").expand();
    await selectKit(".toolbar-popup-menu-options").selectRowByValue(
      "toggleInvisible"
    );

    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.unlist")) > 0,
      "it sets the topic to unlisted"
    );

    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:eq(0) button.reply");
    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.unlist")) === -1,
      "it should reset the state of the composer's model"
    );
  }
);

QUnit.test("Composer with dirty reply can toggle to edit", async assert => {
  await visit("/t/this-is-a-test-topic/9");

  await click(".topic-post:eq(0) button.reply");
  await fillIn(".d-editor-input", "This is a dirty reply");
  await click(".topic-post:eq(0) button.edit");
  assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");
  await click(".modal-footer a:eq(0)");
  assert.equal(
    find(".d-editor-input")
      .val()
      .indexOf("This is the first post."),
    0,
    "it populates the input with the post text"
  );
});

QUnit.test(
  "Composer draft with dirty reply can toggle to edit",
  async assert => {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:eq(0) button.reply");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggler");
    await click(".topic-post:eq(0) button.edit");
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");
    await click(".modal-footer a:eq(0)");
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  }
);

acceptance("Composer and uncategorized is not allowed", {
  loggedIn: true,
  settings: {
    enable_whispers: true,
    allow_uncategorized_topics: false
  }
});

QUnit.test("Disable body until category is selected", async assert => {
  replaceCurrentUser({ admin: false, staff: false, trust_level: 1 });

  await visit("/");
  await click("#create-topic");
  assert.ok(exists(".d-editor-input"), "the composer input is visible");
  assert.ok(
    exists(".title-input .popup-tip.bad.hide"),
    "title errors are hidden by default"
  );
  assert.ok(
    exists(".d-editor-textarea-wrapper .popup-tip.bad.hide"),
    "body errors are hidden by default"
  );
  assert.ok(
    exists(".d-editor-textarea-wrapper.disabled"),
    "textarea is disabled"
  );

  const categoryChooser = selectKit(".category-chooser");

  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(2);

  assert.ok(
    find(".d-editor-textarea-wrapper.disabled").length === 0,
    "textarea is enabled"
  );

  await fillIn(".d-editor-input", "Now I can type stuff");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue("__none__");

  assert.ok(
    find(".d-editor-textarea-wrapper.disabled").length === 0,
    "textarea is still enabled"
  );
});
