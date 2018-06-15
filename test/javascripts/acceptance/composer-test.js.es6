import { acceptance, replaceCurrentUser } from "helpers/qunit-helpers";

acceptance("Composer", {
  loggedIn: true,
  settings: {
    enable_whispers: true
  }
});

QUnit.test("Tests the Composer controls", assert => {
  visit("/");
  andThen(() => {
    assert.ok(exists("#create-topic"), "the create button is visible");
  });

  click("#create-topic");
  andThen(() => {
    assert.ok(exists(".d-editor-input"), "the composer input is visible");
    assert.ok(
      exists(".title-input .popup-tip.bad.hide"),
      "title errors are hidden by default"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.bad.hide"),
      "body errors are hidden by default"
    );
  });

  click("a.toggle-preview");
  andThen(() => {
    assert.ok(
      !exists(".d-editor-preview:visible"),
      "clicking the toggle hides the preview"
    );
  });

  click("a.toggle-preview");
  andThen(() => {
    assert.ok(
      exists(".d-editor-preview:visible"),
      "clicking the toggle shows the preview again"
    );
  });

  click("#reply-control button.create");
  andThen(() => {
    assert.ok(
      !exists(".title-input .popup-tip.bad.hide"),
      "it shows the empty title error"
    );
    assert.ok(
      !exists(".d-editor-wrapper .popup-tip.bad.hide"),
      "it shows the empty body error"
    );
  });

  fillIn("#reply-title", "this is my new topic title");
  andThen(() => {
    assert.ok(exists(".title-input .popup-tip.good"), "the title is now good");
  });

  fillIn(".d-editor-input", "this is the *content* of a post");
  andThen(() => {
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
  });

  andThen(() => {
    const textarea = find("#reply-control .d-editor-input")[0];
    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;

    // Testing keyboard events is tough!
    const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
    const event = document.createEvent("Event");
    event.initEvent("keydown", true, true);
    event[mac ? "metaKey" : "ctrlKey"] = true;
    event.keyCode = 66;

    textarea.dispatchEvent(event);
  });

  andThen(() => {
    const example = I18n.t(`composer.bold_text`);
    assert.equal(
      find("#reply-control .d-editor-input")
        .val()
        .trim(),
      `this is the *content* of a post**${example}**`,
      "it supports keyboard shortcuts"
    );
  });

  click("#reply-control a.cancel");
  andThen(() => {
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");
  });

  click(".modal-footer a:eq(1)");
  andThen(() => {
    assert.ok(!exists(".bootbox.modal"), "the confirmation can be cancelled");
  });
});

QUnit.test("Create a topic with server side errors", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "this title triggers an error");
  fillIn(".d-editor-input", "this is the *content* of a post");
  click("#reply-control button.create");
  andThen(() => {
    assert.ok(exists(".bootbox.modal"), "it pops up an error message");
  });
  click(".bootbox.modal a.btn-primary");
  andThen(() => {
    assert.ok(!exists(".bootbox.modal"), "it dismisses the error");
    assert.ok(exists(".d-editor-input"), "the composer input is visible");
  });
});

QUnit.test("Create a Topic", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "Internationalization Localization");
  fillIn(".d-editor-input", "this is the *content* of a new topic post");
  click("#reply-control button.create");
  andThen(() => {
    assert.equal(
      currentURL(),
      "/t/internationalization-localization/280",
      "it transitions to the newly created topic URL"
    );
  });
});

QUnit.test("Create an enqueued Topic", assert => {
  visit("/");
  click("#create-topic");
  fillIn("#reply-title", "Internationalization Localization");
  fillIn(".d-editor-input", "enqueue this content please");
  click("#reply-control button.create");
  andThen(() => {
    assert.ok(visible(".d-modal"), "it pops up a modal");
    assert.equal(currentURL(), "/", "it doesn't change routes");
  });

  click(".modal-footer button");
  andThen(() => {
    assert.ok(invisible(".d-modal"), "the modal can be dismissed");
  });
});

QUnit.test("Create a Reply", assert => {
  visit("/t/internationalization-localization/280");

  andThen(() => {
    assert.ok(
      !exists("article[data-post-id=12345]"),
      "the post is not in the DOM"
    );
  });

  click("#topic-footer-buttons .btn.create");
  andThen(() => {
    assert.ok(exists(".d-editor-input"), "the composer input is visible");
    assert.ok(
      !exists("#reply-title"),
      "there is no title since this is a reply"
    );
  });

  fillIn(".d-editor-input", "this is the content of my reply");
  click("#reply-control button.create");
  andThen(() => {
    assert.equal(
      find(".cooked:last p").text(),
      "this is the content of my reply"
    );
  });
});

QUnit.test("Posting on a different topic", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  fillIn(".d-editor-input", "this is the content for a different topic");

  visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
  andThen(function() {
    assert.equal(currentURL(), "/t/1-3-0beta9-no-rate-limit-popups/28830");
  });
  click("#reply-control button.create");
  andThen(function() {
    assert.ok(visible(".reply-where-modal"), "it pops up a modal");
  });

  click(".btn-reply-here");
  andThen(() => {
    assert.equal(
      find(".cooked:last p").text(),
      "this is the content for a different topic"
    );
  });
});

QUnit.test("Create an enqueued Reply", assert => {
  visit("/t/internationalization-localization/280");

  click("#topic-footer-buttons .btn.create");
  andThen(() => {
    assert.ok(exists(".d-editor-input"), "the composer input is visible");
    assert.ok(
      !exists("#reply-title"),
      "there is no title since this is a reply"
    );
  });

  fillIn(".d-editor-input", "enqueue this content please");
  click("#reply-control button.create");
  andThen(() => {
    assert.ok(
      find(".cooked:last p").text() !== "enqueue this content please",
      "it doesn't insert the post"
    );
  });

  andThen(() => {
    assert.ok(visible(".d-modal"), "it pops up a modal");
  });

  click(".modal-footer button");
  andThen(() => {
    assert.ok(invisible(".d-modal"), "the modal can be dismissed");
  });
});

QUnit.test("Edit the first post", assert => {
  visit("/t/internationalization-localization/280");

  assert.ok(
    !exists(".topic-post:eq(0) .post-info.edits"),
    "it has no edits icon at first"
  );

  click(".topic-post:eq(0) button.show-more-actions");
  click(".topic-post:eq(0) button.edit");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("Any plans to support"),
      0,
      "it populates the input with the post text"
    );
  });

  fillIn(".d-editor-input", "This is the new text for the post");
  fillIn("#reply-title", "This is the new text for the title");
  click("#reply-control button.create");
  andThen(() => {
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
});

QUnit.test("Composer can switch between edits", assert => {
  visit("/t/this-is-a-test-topic/9");

  click(".topic-post:eq(0) button.edit");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });
  click(".topic-post:eq(1) button.edit");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  });
});

QUnit.test("Composer with dirty edit can toggle to another edit", assert => {
  visit("/t/this-is-a-test-topic/9");

  click(".topic-post:eq(0) button.edit");
  fillIn(".d-editor-input", "This is a dirty reply");
  click(".topic-post:eq(1) button.edit");
  andThen(() => {
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");
  });
  click(".modal-footer a:eq(0)");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  });
});

QUnit.test("Composer can toggle between edit and reply", assert => {
  visit("/t/this-is-a-test-topic/9");

  click(".topic-post:eq(0) button.edit");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });
  click(".topic-post:eq(0) button.reply");
  andThen(() => {
    assert.equal(find(".d-editor-input").val(), "", "it clears the input");
  });
  click(".topic-post:eq(0) button.edit");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });
});

QUnit.test("Composer can toggle between reply and createTopic", assert => {
  visit("/t/this-is-a-test-topic/9");
  click(".topic-post:eq(0) button.reply");

  selectKit(".toolbar-popup-menu-options")
    .expand()
    .selectRowByValue("toggleWhisper");

  andThen(() => {
    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.whisper")) > 0,
      "it sets the post type to whisper"
    );
  });

  visit("/");
  andThen(() => {
    assert.ok(exists("#create-topic"), "the create topic button is visible");
  });

  click("#create-topic");
  andThen(() => {
    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.whisper")) === -1,
      "it should reset the state of the composer's model"
    );
  });

  selectKit(".toolbar-popup-menu-options")
    .expand()
    .selectRowByValue("toggleInvisible");

  andThen(() => {
    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.unlist")) > 0,
      "it sets the topic to unlisted"
    );
  });

  visit("/t/this-is-a-test-topic/9");

  click(".topic-post:eq(0) button.reply");
  andThen(() => {
    assert.ok(
      find(".composer-fields .whisper")
        .text()
        .indexOf(I18n.t("composer.unlist")) === -1,
      "it should reset the state of the composer's model"
    );
  });
});

QUnit.test("Composer with dirty reply can toggle to edit", assert => {
  visit("/t/this-is-a-test-topic/9");

  click(".topic-post:eq(0) button.reply");
  fillIn(".d-editor-input", "This is a dirty reply");
  click(".topic-post:eq(0) button.edit");
  andThen(() => {
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");
  });
  click(".modal-footer a:eq(0)");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });
});

QUnit.test("Composer draft with dirty reply can toggle to edit", assert => {
  visit("/t/this-is-a-test-topic/9");

  click(".topic-post:eq(0) button.reply");
  fillIn(".d-editor-input", "This is a dirty reply");
  click(".toggler");
  click(".topic-post:eq(0) button.edit");
  andThen(() => {
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");
  });
  click(".modal-footer a:eq(0)");
  andThen(() => {
    assert.equal(
      find(".d-editor-input")
        .val()
        .indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });
});

acceptance("Composer and uncategorized is not allowed", {
  loggedIn: true,
  settings: {
    enable_whispers: true,
    allow_uncategorized_topics: false
  }
});

QUnit.test("Disable body until category is selected", assert => {
  replaceCurrentUser({ admin: false, staff: false, trust_level: 1 });

  visit("/");
  click("#create-topic");
  andThen(() => {
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
  });

  const categoryChooser = selectKit(".category-chooser");

  categoryChooser.expand().selectRowByValue(2);

  andThen(() => {
    assert.ok(
      find(".d-editor-textarea-wrapper.disabled").length === 0,
      "textarea is enabled"
    );
  });

  fillIn(".d-editor-input", "Now I can type stuff");
  categoryChooser.expand().selectRowByValue("__none__");

  andThen(() => {
    assert.ok(
      find(".d-editor-textarea-wrapper.disabled").length === 0,
      "textarea is still enabled"
    );
  });
});
