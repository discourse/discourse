import {
  acceptance,
  count,
  exists,
  invisible,
  query,
  queryAll,
  updateCurrentUser,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { skip, test } from "qunit";
import Draft from "discourse/models/draft";
import I18n from "I18n";
import { NEW_TOPIC_KEY } from "discourse/models/composer";
import { Promise } from "rsvp";
import { run } from "@ember/runloop";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import sinon from "sinon";
import { toggleCheckDraftPopup } from "discourse/controllers/composer";
import LinkLookup from "discourse/lib/link-lookup";

acceptance("Composer", function (needs) {
  needs.user();
  needs.settings({ enable_whispers: true });
  needs.site({ can_tag_topics: true });
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
    server.get("/posts/419", () => {
      return helper.response({ id: 419 });
    });
    server.get("/u/is_local_username", () => {
      return helper.response({
        valid: [],
        valid_groups: ["staff"],
        mentionable_groups: [{ name: "staff", user_count: 30 }],
        cannot_see: [],
        max_users_notified_per_group_mention: 100,
      });
    });
  });

  skip("Tests the Composer controls", async function (assert) {
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
      queryAll(".d-editor-preview").html().trim(),
      "<p>this is the <em>content</em> of a post</p>",
      "it previews content"
    );
    assert.ok(
      exists(".d-editor-textarea-wrapper .popup-tip.good"),
      "the body is now good"
    );

    const textarea = query("#reply-control .d-editor-input");
    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;

    // Testing keyboard events is tough!
    const mac = /Mac|iPod|iPhone|iPad/.test(navigator.platform);
    const event = document.createEvent("Event");
    event.initEvent("keydown", true, true);
    event[mac ? "metaKey" : "ctrlKey"] = true;
    event.keyCode = 66;

    run(() => textarea.dispatchEvent(event));

    const example = I18n.t(`composer.bold_text`);
    assert.equal(
      queryAll("#reply-control .d-editor-input").val().trim(),
      `this is the *content* of a post**${example}**`,
      "it supports keyboard shortcuts"
    );

    await click("#reply-control a.cancel");
    assert.ok(exists(".bootbox.modal"), "it pops up a confirmation dialog");

    await click(".modal-footer a:nth-of-type(2)");
    assert.ok(!exists(".bootbox.modal"), "the confirmation can be cancelled");
  });

  test("Create a topic with server side errors", async function (assert) {
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

  test("Create a Topic", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Internationalization Localization");
    await fillIn(
      ".d-editor-input",
      "this is the *content* of a new topic post"
    );
    await click("#reply-control button.create");
    assert.equal(
      currentURL(),
      "/t/internationalization-localization/280",
      "it transitions to the newly created topic URL"
    );
  });

  test("Create an enqueued Topic", async function (assert) {
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

  test("Can display a message and route to a URL", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "This title doesn't matter");
    await fillIn(".d-editor-input", "custom message");
    await click("#reply-control button.create");
    assert.equal(
      queryAll(".bootbox .modal-body").text(),
      "This is a custom response"
    );
    assert.equal(currentURL(), "/", "it doesn't change routes");

    await click(".bootbox .btn-primary");
    assert.equal(
      currentURL(),
      "/faq",
      "can navigate to a `route_to` destination"
    );
  });

  test("Create a Reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.ok(
      !exists('article[data-post-id="12345"]'),
      "the post is not in the DOM"
    );

    await click("#topic-footer-buttons .btn.create");
    assert.ok(exists(".d-editor-input"), "the composer input is visible");
    assert.ok(
      !exists("#reply-title"),
      "there is no title since this is a reply"
    );

    await fillIn(".d-editor-input", "this is the content of my reply");
    await click("#reply-control button.create");
    assert.equal(
      queryAll(".cooked:last p").text(),
      "If you use gettext format you could leverage Launchpad 13 translations and the community behind it."
    );
  });

  test("Can edit a post after starting a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .create");
    await fillIn(".d-editor-input", "this is the content of my reply");

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    await click(".modal-footer button.keep-editing");
    assert.ok(invisible(".discard-draft-modal.modal"));
    assert.equal(
      queryAll(".d-editor-input").val(),
      "this is the content of my reply",
      "composer does not switch when using Keep Editing button"
    );

    await click(".topic-post:nth-of-type(1) button.edit");
    await click(".modal-footer button.save-draft");
    assert.ok(invisible(".discard-draft-modal.modal"));

    assert.equal(
      queryAll(".d-editor-input").val(),
      queryAll(".topic-post:nth-of-type(1) .cooked > p").text(),
      "composer has contents of post to be edited"
    );
  });

  test("Posting on a different topic", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(
      ".d-editor-input",
      "this is the content for a different topic"
    );

    await visit("/t/1-3-0beta9-no-rate-limit-popups/28830");
    assert.equal(currentURL(), "/t/1-3-0beta9-no-rate-limit-popups/28830");
    await click("#reply-control button.create");
    assert.ok(visible(".reply-where-modal"), "it pops up a modal");

    await click(".btn-reply-here");
    assert.equal(
      queryAll(".cooked:last p").text(),
      "If you use gettext format you could leverage Launchpad 13 translations and the community behind it."
    );
  });

  test("Discard draft modal works when switching topics", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", "this is the content of the first reply");

    await visit("/t/this-is-a-test-topic/9");
    assert.equal(currentURL(), "/t/this-is-a-test-topic/9");
    await click("#topic-footer-buttons .btn.create");
    assert.ok(
      exists(".discard-draft-modal.modal"),
      "it pops up the discard drafts modal"
    );

    await click(".modal-footer button.keep-editing");

    assert.ok(invisible(".discard-draft-modal.modal"));
    await click("#topic-footer-buttons .btn.create");
    assert.ok(
      exists(".discard-draft-modal.modal"),
      "it pops up the modal again"
    );

    await click(".modal-footer button.discard-draft");

    assert.equal(
      queryAll(".d-editor-input").val(),
      "",
      "discards draft and reset composer textarea"
    );
  });

  test("Create an enqueued Reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.ok(!exists(".pending-posts .reviewable-item"));

    await click("#topic-footer-buttons .btn.create");
    assert.ok(exists(".d-editor-input"), "the composer input is visible");
    assert.ok(
      !exists("#reply-title"),
      "there is no title since this is a reply"
    );

    await fillIn(".d-editor-input", "enqueue this content please");
    await click("#reply-control button.create");
    assert.ok(
      queryAll(".cooked:last p").text() !== "enqueue this content please",
      "it doesn't insert the post"
    );

    assert.ok(visible(".d-modal"), "it pops up a modal");

    await click(".modal-footer button");
    assert.ok(invisible(".d-modal"), "the modal can be dismissed");

    assert.ok(exists(".pending-posts .reviewable-item"));
  });

  test("Edit the first post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.ok(
      !exists(".topic-post:nth-of-type(1) .post-info.edits"),
      "it has no edits icon at first"
    );

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("Any plans to support"),
      0,
      "it populates the input with the post text"
    );

    await fillIn(".d-editor-input", "This is the new text for the post");
    await fillIn("#reply-title", "This is the new text for the title");
    await click("#reply-control button.create");
    assert.ok(!exists(".d-editor-input"), "it closes the composer");
    assert.ok(
      exists(".topic-post:nth-of-type(1) .post-info.edits"),
      "it has the edits icon"
    );
    assert.ok(
      queryAll("#topic-title h1")
        .text()
        .indexOf("This is the new text for the title") !== -1,
      "it shows the new title"
    );
    assert.ok(
      queryAll(".topic-post:nth-of-type(1) .cooked")
        .text()
        .indexOf("This is the new text for the post") !== -1,
      "it updates the post"
    );
  });

  test("Editing a post stages new content", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    await fillIn(".d-editor-input", "will return empty json");
    await fillIn("#reply-title", "This is the new text for the title");

    // when this promise resolves, the request had already started because
    // this promise will be resolved by the pretender
    const promise = new Promise((resolve) => {
      window.resolveLastPromise = resolve;
    });

    // click to trigger the save, but wait until the request starts
    click("#reply-control button.create");
    await promise;

    // at this point, request is in flight, so post is staged
    assert.equal(count(".topic-post.staged"), 1);
    assert.ok(
      find(".topic-post:nth-of-type(1)")[0].className.includes("staged")
    );
    assert.equal(
      find(".topic-post.staged .cooked").text().trim(),
      "will return empty json"
    );

    // finally, finish request and wait for last render
    window.resolveLastPromise();
    await visit("/t/internationalization-localization/280");

    assert.equal(count(".topic-post.staged"), 0);
  });

  QUnit.skip(
    "Editing a post can rollback to old content",
    async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click(".topic-post:nth-of-type(1) button.show-more-actions");
      await click(".topic-post:nth-of-type(1) button.edit");

      await fillIn(".d-editor-input", "this will 409");
      await fillIn("#reply-title", "This is the new text for the title");
      await click("#reply-control button.create");

      assert.ok(!exists(".topic-post.staged"));
      assert.equal(
        find(".topic-post .cooked")[0].innerText,
        "Any plans to support localization of UI elements, so that I (for example) could set up a completely German speaking forum?"
      );

      await click(".bootbox.modal .btn-primary");
    }
  );

  test("Composer can switch between edits", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
    await click(".topic-post:nth-of-type(2) button.edit");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  });

  test("Composer with dirty edit can toggle to another edit", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".topic-post:nth-of-type(2) button.edit");
    assert.ok(
      exists(".discard-draft-modal.modal"),
      "it pops up a confirmation dialog"
    );

    await click(".modal-footer button.discard-draft");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  });

  test("Composer can toggle between edit and reply", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
    await click(".topic-post:nth-of-type(1) button.reply");
    assert.equal(queryAll(".d-editor-input").val(), "", "it clears the input");
    await click(".topic-post:nth-of-type(1) button.edit");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });

  test("Composer can toggle whispers", async function (assert) {
    const menu = selectKit(".toolbar-popup-menu-options");

    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    await menu.expand();
    await menu.selectRowByValue("toggleWhisper");

    assert.equal(
      count(".composer-actions svg.d-icon-far-eye-slash"),
      1,
      "it sets the post type to whisper"
    );

    await menu.expand();
    await menu.selectRowByValue("toggleWhisper");

    assert.ok(
      !exists(".composer-actions svg.d-icon-far-eye-slash"),
      "it removes the whisper mode"
    );

    await menu.expand();
    await menu.selectRowByValue("toggleWhisper");

    await click(".toggle-fullscreen");

    await menu.expand();

    assert.ok(
      menu.rowByValue("toggleWhisper").exists(),
      "whisper toggling is still present when going fullscreen"
    );
  });

  test("Composer can toggle layouts (open, fullscreen and draft)", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    assert.equal(
      count("#reply-control.open"),
      1,
      "it starts in open state by default"
    );

    await click(".toggle-fullscreen");

    assert.equal(
      count("#reply-control.fullscreen"),
      1,
      "it expands composer to full screen"
    );

    await click(".toggle-fullscreen");

    assert.equal(
      count("#reply-control.open"),
      1,
      "it collapses composer to regular size"
    );

    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggler");

    assert.equal(
      count("#reply-control.draft"),
      1,
      "it collapses composer to draft bar"
    );

    await click(".toggle-fullscreen");

    assert.equal(
      count("#reply-control.open"),
      1,
      "from draft, it expands composer back to open state"
    );
  });

  test("Composer can toggle between reply and createTopic", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    await selectKit(".toolbar-popup-menu-options").expand();
    await selectKit(".toolbar-popup-menu-options").selectRowByValue(
      "toggleWhisper"
    );

    assert.equal(
      count(".composer-actions svg.d-icon-far-eye-slash"),
      1,
      "it sets the post type to whisper"
    );

    await visit("/");
    assert.ok(exists("#create-topic"), "the create topic button is visible");

    await click("#create-topic");
    assert.ok(
      !exists(".composer-fields .whisper .d-icon-far-eye-slash"),
      "it should reset the state of the composer's model"
    );

    await selectKit(".toolbar-popup-menu-options").expand();
    await selectKit(".toolbar-popup-menu-options").selectRowByValue(
      "toggleInvisible"
    );

    assert.ok(
      queryAll(".composer-fields .unlist")
        .text()
        .indexOf(I18n.t("composer.unlist")) > 0,
      "it sets the topic to unlisted"
    );

    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    assert.ok(
      !exists(".composer-fields .whisper"),
      "it should reset the state of the composer's model"
    );
  });

  test("Composer with dirty reply can toggle to edit", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".topic-post:nth-of-type(1) button.edit");
    assert.ok(
      exists(".discard-draft-modal.modal"),
      "it pops up a confirmation dialog"
    );
    await click(".modal-footer button.discard-draft");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
  });

  test("Composer draft with dirty reply can toggle to edit", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggler");
    await click(".topic-post:nth-of-type(2) button.edit");
    assert.ok(
      exists(".discard-draft-modal.modal"),
      "it pops up a confirmation dialog"
    );
    assert.equal(
      queryAll(".modal-footer button.save-draft").text().trim(),
      I18n.t("post.cancel_composer.save_draft"),
      "has save draft button"
    );
    assert.equal(
      queryAll(".modal-footer button.keep-editing").text().trim(),
      I18n.t("post.cancel_composer.keep_editing"),
      "has keep editing button"
    );
    await click(".modal-footer button.save-draft");
    assert.equal(
      queryAll(".d-editor-input").val().indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  });

  test("Composer draft can switch to draft in new context without destroying current draft", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(".d-editor-input", "This is a dirty reply");

    await click("#site-logo");
    await click("#create-topic");

    assert.ok(
      exists(".discard-draft-modal.modal"),
      "it pops up a confirmation dialog"
    );
    assert.equal(
      queryAll(".modal-footer button.save-draft").text().trim(),
      I18n.t("post.cancel_composer.save_draft"),
      "has save draft button"
    );
    assert.equal(
      queryAll(".modal-footer button.keep-editing").text().trim(),
      I18n.t("post.cancel_composer.keep_editing"),
      "has keep editing button"
    );
    await click(".modal-footer button.save-draft");
    assert.equal(
      queryAll(".d-editor-input").val(),
      "",
      "it clears the composer input"
    );
  });

  test("Checks for existing draft", async function (assert) {
    try {
      toggleCheckDraftPopup(true);

      await visit("/t/internationalization-localization/280");

      await click(".topic-post:nth-of-type(1) button.show-more-actions");
      await click(".topic-post:nth-of-type(1) button.edit");

      assert.equal(
        queryAll(".modal-body").text(),
        I18n.t("drafts.abandon.confirm")
      );

      await click(".modal-footer .btn.btn-default");
    } finally {
      toggleCheckDraftPopup(false);
    }
  });

  test("Can switch states without abandon popup", async function (assert) {
    try {
      toggleCheckDraftPopup(true);

      await visit("/t/internationalization-localization/280");

      const longText = "a".repeat(256);

      sinon.stub(Draft, "get").returns(
        Promise.resolve({
          draft: null,
          draft_sequence: 0,
        })
      );

      await click(".btn-primary.create.btn");

      await fillIn(".d-editor-input", longText);

      assert.ok(
        exists(
          '.action-title a[href="/t/internationalization-localization/280"]'
        ),
        "the mode should be: reply to post"
      );

      await click("article#post_3 button.reply");

      const composerActions = selectKit(".composer-actions");
      await composerActions.expand();
      await composerActions.selectRowByValue("reply_as_private_message");

      assert.ok(!exists(".modal-body"), "abandon popup shouldn't come");

      assert.ok(
        queryAll(".d-editor-input").val().includes(longText),
        "entered text should still be there"
      );

      assert.ok(
        !exists(
          '.action-title a[href="/t/internationalization-localization/280"]'
        ),
        "mode should have changed"
      );
    } finally {
      toggleCheckDraftPopup(false);
    }
    sinon.restore();
  });

  test("Loading draft also replaces the recipients", async function (assert) {
    try {
      toggleCheckDraftPopup(true);

      sinon.stub(Draft, "get").returns(
        Promise.resolve({
          draft:
            '{"reply":"hello","action":"privateMessage","title":"hello","categoryId":null,"archetypeId":"private_message","metaData":null,"recipients":"codinghorror","composerTime":9159,"typingTime":2500}',
          draft_sequence: 0,
        })
      );

      await visit("/u/charlie");
      await click("button.compose-pm");
      await click(".modal .btn-default");

      assert.equal(
        queryAll("#private-message-users .selected-name:nth-of-type(1)")
          .text()
          .trim(),
        "codinghorror"
      );
    } finally {
      toggleCheckDraftPopup(false);
    }
  });

  test("Loads tags and category from draft payload", async function (assert) {
    updateCurrentUser({ has_topic_draft: true });

    sinon.stub(Draft, "get").returns(
      Promise.resolve({
        draft:
          '{"reply":"Hey there","action":"createTopic","title":"Draft topic","categoryId":2,"tags":["fun", "times"],"archetypeId":"regular","metaData":null,"composerTime":25269,"typingTime":8100}',
        draft_sequence: 0,
        draft_key: NEW_TOPIC_KEY,
      })
    );

    await visit("/latest");
    assert.equal(
      queryAll("#create-topic").text().trim(),
      I18n.t("topic.open_draft")
    );

    await click("#create-topic");
    assert.equal(selectKit(".category-chooser").header().value(), "2");
    assert.equal(selectKit(".mini-tag-chooser").header().value(), "fun,times");
  });

  test("Deleting the text content of the first post in a private message", async function (assert) {
    await visit("/t/34");

    await click("#post_1 .d-icon-ellipsis-h");

    await click("#post_1 .d-icon-pencil-alt");

    await fillIn(".d-editor-input", "");

    assert.equal(
      queryAll(".d-editor-container textarea").attr("placeholder"),
      I18n.t("composer.reply_placeholder"),
      "it should not block because of missing category"
    );
  });

  const assertImageResized = (assert, uploads) => {
    assert.equal(
      queryAll(".d-editor-input").val(),
      uploads.join("\n"),
      "it resizes uploaded image"
    );
  };

  test("reply button has envelope icon when replying to private message", async function (assert) {
    await visit("/t/34");
    await click("article#post_3 button.reply");
    assert.equal(
      queryAll(".save-or-cancel button.create").text().trim(),
      I18n.t("composer.create_pm"),
      "reply button says Message"
    );
    assert.equal(
      count(".save-or-cancel button.create svg.d-icon-envelope"),
      1,
      "reply button has envelope icon"
    );
  });

  test("edit button when editing a post in a PM", async function (assert) {
    await visit("/t/34");
    await click("article#post_3 button.show-more-actions");
    await click("article#post_3 button.edit");

    assert.equal(
      queryAll(".save-or-cancel button.create").text().trim(),
      I18n.t("composer.save_edit"),
      "save button says Save Edit"
    );
    assert.equal(
      count(".save-or-cancel button.create svg.d-icon-pencil-alt"),
      1,
      "save button has pencil icon"
    );
  });

  test("Image resizing buttons", async function (assert) {
    await visit("/");
    await click("#create-topic");

    let uploads = [
      // 0 Default markdown with dimensions- should work
      "<a href='https://example.com'>![test|690x313](upload://test.png)</a>",
      // 1 Image with scaling percentage, should work
      "![test|690x313,50%](upload://test.png)",
      // 2 image with scaling percentage and a proceeding whitespace, should work
      "![test|690x313, 50%](upload://test.png)",
      // 3 No dimensions, should not work
      "![test](upload://test.jpeg)",
      // 4 Wrapped in backticks should not work
      "`![test|690x313](upload://test.png)`",
      // 5 html image - should not work
      "<img src='/images/avatar.png' wight='20' height='20'>",
      // 6 two images one the same line, but both are syntactically correct - both should work
      "![onTheSameLine1|200x200](upload://onTheSameLine1.jpeg) ![onTheSameLine2|250x250](upload://onTheSameLine2.jpeg)",
      // 7 & 8 Identical images - both should work
      "![identicalImage|300x300](upload://identicalImage.png)",
      "![identicalImage|300x300](upload://identicalImage.png)",
      // 9 Image with whitespaces in alt - should work
      "![image with spaces in alt|690x220](upload://test.png)",
      // 10 Image with markdown title - should work
      `![image|690x220](upload://test.png "image title")`,
      // 11 bbcode - should not work
      "[img]/images/avatar.png[/img]",
      // 12 Image with data attributes
      "![test|foo=bar|690x313,50%|bar=baz](upload://test.png)",
    ];

    await fillIn(".d-editor-input", uploads.join("\n"));

    assert.equal(
      count(".button-wrapper"),
      10,
      "it adds correct amount of scaling button groups"
    );

    // Default
    uploads[0] =
      "<a href='https://example.com'>![test|690x313, 50%](upload://test.png)</a>";
    await click(
      queryAll(
        ".button-wrapper[data-image-index='0'] .scale-btn[data-scale='50']"
      )[0]
    );
    assertImageResized(assert, uploads);

    // Targets the correct image if two on the same line
    uploads[6] =
      "![onTheSameLine1|200x200, 50%](upload://onTheSameLine1.jpeg) ![onTheSameLine2|250x250](upload://onTheSameLine2.jpeg)";
    await click(
      queryAll(
        ".button-wrapper[data-image-index='3'] .scale-btn[data-scale='50']"
      )[0]
    );
    assertImageResized(assert, uploads);

    // Try the other image on the same line
    uploads[6] =
      "![onTheSameLine1|200x200, 50%](upload://onTheSameLine1.jpeg) ![onTheSameLine2|250x250, 75%](upload://onTheSameLine2.jpeg)";
    await click(
      queryAll(
        ".button-wrapper[data-image-index='4'] .scale-btn[data-scale='75']"
      )[0]
    );
    assertImageResized(assert, uploads);

    // Make sure we target the correct image if there are duplicates
    uploads[7] = "![identicalImage|300x300, 50%](upload://identicalImage.png)";
    await click(
      queryAll(
        ".button-wrapper[data-image-index='5'] .scale-btn[data-scale='50']"
      )[0]
    );
    assertImageResized(assert, uploads);

    // Try the other dupe
    uploads[8] = "![identicalImage|300x300, 75%](upload://identicalImage.png)";
    await click(
      queryAll(
        ".button-wrapper[data-image-index='6'] .scale-btn[data-scale='75']"
      )[0]
    );
    assertImageResized(assert, uploads);

    // Don't mess with image titles
    uploads[10] = `![image|690x220, 75%](upload://test.png "image title")`;
    await click(
      queryAll(
        ".button-wrapper[data-image-index='8'] .scale-btn[data-scale='75']"
      )[0]
    );
    assertImageResized(assert, uploads);

    // Keep data attributes
    uploads[12] = `![test|foo=bar|690x313, 75%|bar=baz](upload://test.png)`;
    await click(
      queryAll(
        ".button-wrapper[data-image-index='9'] .scale-btn[data-scale='75']"
      )[0]
    );
    assertImageResized(assert, uploads);

    await fillIn(
      ".d-editor-input",
      `
![test|690x313](upload://test.png)

\`<script>alert("xss")</script>\`
    `
    );

    assert.ok(
      !exists("script"),
      "it does not unescape script tags in code blocks"
    );
  });

  skip("Shows duplicate_link notice", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");

    this.container.lookup("controller:composer").set(
      "linkLookup",
      new LinkLookup({
        "github.com": {
          domain: "github.com",
          username: "system",
          posted_at: "2021-01-01T12:00:00.000Z",
          post_number: 1,
        },
      })
    );

    await fillIn(".d-editor-input", "[](https://discourse.org)");
    assert.ok(!exists(".composer-popup"));

    await fillIn(".d-editor-input", "[quote][](https://github.com)[/quote]");
    assert.ok(!exists(".composer-popup"));

    await fillIn(".d-editor-input", "[](https://github.com)");
    assert.equal(count(".composer-popup"), 1);
  });

  test("Shows the 'group_mentioned' notice", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");

    await fillIn(".d-editor-input", "[quote]\n@staff\n[/quote]");
    assert.notOk(
      exists(".composer-popup"),
      "Doesn't show the 'group_mentioned' notice in a quote"
    );

    await fillIn(".d-editor-input", "@staff");
    assert.ok(exists(".composer-popup"), "Shows the 'group_mentioned' notice");
  });
});
