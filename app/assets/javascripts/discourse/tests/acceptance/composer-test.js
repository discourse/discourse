import { run } from "@ember/runloop";
import { click, currentURL, fillIn, settled, visit } from "@ember/test-helpers";
import { toggleCheckDraftPopup } from "discourse/controllers/composer";
import LinkLookup from "discourse/lib/link-lookup";
import { withPluginApi } from "discourse/lib/plugin-api";
import Composer, {
  CREATE_TOPIC,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
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
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "I18n";
import { skip, test } from "qunit";
import { Promise } from "rsvp";
import sinon from "sinon";

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

  test("Tests the Composer controls", async function (assert) {
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

    await click(".toggle-preview");
    assert.ok(
      !exists(".d-editor-preview:visible"),
      "clicking the toggle hides the preview"
    );

    await click(".toggle-preview");
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
    assert.strictEqual(
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
    event.key = "B";
    event.keyCode = 66;

    run(() => textarea.dispatchEvent(event));

    const example = I18n.t(`composer.bold_text`);
    assert.strictEqual(
      queryAll("#reply-control .d-editor-input").val().trim(),
      `this is the *content* of a post**${example}**`,
      "it supports keyboard shortcuts"
    );

    await click("#reply-control a.cancel");
    assert.ok(exists(".d-modal"), "it pops up a confirmation dialog");

    await click(".modal-footer .discard-draft");
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
    assert.strictEqual(
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
    assert.strictEqual(currentURL(), "/", "it doesn't change routes");

    await click(".modal-footer button");
    assert.ok(invisible(".d-modal"), "the modal can be dismissed");
  });

  test("Can display a message and route to a URL", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "This title doesn't matter");
    await fillIn(".d-editor-input", "custom message");
    await click("#reply-control button.create");
    assert.strictEqual(
      queryAll(".bootbox .modal-body").text(),
      "This is a custom response"
    );
    assert.strictEqual(currentURL(), "/", "it doesn't change routes");

    await click(".bootbox .btn-primary");
    assert.strictEqual(
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
    assert.strictEqual(
      queryAll(".cooked:last p").text(),
      "this is the content of my reply"
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
    assert.strictEqual(
      queryAll(".d-editor-input").val(),
      "this is the content of my reply",
      "composer does not switch when using Keep Editing button"
    );

    await click(".topic-post:nth-of-type(1) button.edit");
    await click(".modal-footer button.save-draft");
    assert.ok(invisible(".discard-draft-modal.modal"));

    assert.strictEqual(
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
    assert.strictEqual(
      currentURL(),
      "/t/1-3-0beta9-no-rate-limit-popups/28830"
    );
    await click("#reply-control button.create");
    assert.ok(visible(".reply-where-modal"), "it pops up a modal");

    await click(".btn-reply-here");
    assert.strictEqual(
      queryAll(".cooked:last p").text(),
      "If you use gettext format you could leverage Launchpad 13 translations and the community behind it."
    );
  });

  test("Discard draft modal works when switching topics", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", "this is the content of the first reply");

    await visit("/t/this-is-a-test-topic/9");
    assert.strictEqual(currentURL(), "/t/this-is-a-test-topic/9");
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

    assert.strictEqual(
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
    assert.strictEqual(
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
    assert.strictEqual(count(".topic-post.staged"), 1);
    assert.ok(query(".topic-post:nth-of-type(1)").className.includes("staged"));
    assert.strictEqual(
      query(".topic-post.staged .cooked").innerText.trim(),
      "will return empty json"
    );

    // finally, finish request and wait for last render
    window.resolveLastPromise();
    await visit("/t/internationalization-localization/280");

    assert.strictEqual(count(".topic-post.staged"), 0);
  });

  test("Composer can switch between edits", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert.strictEqual(
      queryAll(".d-editor-input").val().indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
    await click(".topic-post:nth-of-type(2) button.edit");
    assert.strictEqual(
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
    assert.strictEqual(
      queryAll(".d-editor-input").val().indexOf("This is the second post."),
      0,
      "it populates the input with the post text"
    );
  });

  test("Composer can toggle between edit and reply", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert.strictEqual(
      queryAll(".d-editor-input").val().indexOf("This is the first post."),
      0,
      "it populates the input with the post text"
    );
    await click(".topic-post:nth-of-type(1) button.reply");
    assert.strictEqual(
      queryAll(".d-editor-input").val(),
      "",
      "it clears the input"
    );
    await click(".topic-post:nth-of-type(1) button.edit");
    assert.strictEqual(
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

    assert.strictEqual(
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

    assert.strictEqual(
      count("#reply-control.open"),
      1,
      "it starts in open state by default"
    );

    await click(".toggle-fullscreen");

    assert.strictEqual(
      count("#reply-control.fullscreen"),
      1,
      "it expands composer to full screen"
    );

    await click(".toggle-fullscreen");

    assert.strictEqual(
      count("#reply-control.open"),
      1,
      "it collapses composer to regular size"
    );

    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggler");

    assert.strictEqual(
      count("#reply-control.draft"),
      1,
      "it collapses composer to draft bar"
    );

    await click(".toggle-fullscreen");

    assert.strictEqual(
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

    assert.strictEqual(
      count(".composer-actions svg.d-icon-far-eye-slash"),
      1,
      "it sets the post type to whisper"
    );

    await visit("/");
    assert.ok(exists("#create-topic"), "the create topic button is visible");

    await click("#create-topic");
    assert.ok(
      !exists(".reply-details .whisper .d-icon-far-eye-slash"),
      "it should reset the state of the composer's model"
    );

    await selectKit(".toolbar-popup-menu-options").expand();
    await selectKit(".toolbar-popup-menu-options").selectRowByValue(
      "toggleInvisible"
    );

    assert.ok(
      query(".reply-details .unlist").innerText.includes(
        I18n.t("composer.unlist")
      ),
      "it sets the topic to unlisted"
    );

    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    assert.ok(
      !exists(".reply-details .whisper"),
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
    assert.strictEqual(
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
    assert.strictEqual(
      queryAll(".modal-footer button.save-draft").text().trim(),
      I18n.t("post.cancel_composer.save_draft"),
      "has save draft button"
    );
    assert.strictEqual(
      queryAll(".modal-footer button.keep-editing").text().trim(),
      I18n.t("post.cancel_composer.keep_editing"),
      "has keep editing button"
    );
    await click(".modal-footer button.save-draft");
    assert.strictEqual(
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
    assert.strictEqual(
      queryAll(".modal-footer button.save-draft").text().trim(),
      I18n.t("post.cancel_composer.save_draft"),
      "has save draft button"
    );
    assert.strictEqual(
      queryAll(".modal-footer button.keep-editing").text().trim(),
      I18n.t("post.cancel_composer.keep_editing"),
      "has keep editing button"
    );
    await click(".modal-footer button.save-draft");
    assert.strictEqual(
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

      assert.strictEqual(
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

      const privateMessageUsers = selectKit("#private-message-users");
      assert.strictEqual(privateMessageUsers.header().value(), "codinghorror");
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
    assert.strictEqual(
      queryAll("#create-topic").text().trim(),
      I18n.t("topic.open_draft")
    );

    await click("#create-topic");
    assert.strictEqual(selectKit(".category-chooser").header().value(), "2");
    assert.strictEqual(
      selectKit(".mini-tag-chooser").header().value(),
      "fun,times"
    );
  });

  test("Deleting the text content of the first post in a private message", async function (assert) {
    await visit("/t/34");

    await click("#post_1 .d-icon-ellipsis-h");

    await click("#post_1 .d-icon-pencil-alt");

    await fillIn(".d-editor-input", "");

    assert.strictEqual(
      queryAll(".d-editor-container textarea").attr("placeholder"),
      I18n.t("composer.reply_placeholder"),
      "it should not block because of missing category"
    );
  });

  test("reply button has envelope icon when replying to private message", async function (assert) {
    await visit("/t/34");
    await click("article#post_3 button.reply");
    assert.strictEqual(
      queryAll(".save-or-cancel button.create").text().trim(),
      I18n.t("composer.create_pm"),
      "reply button says Message"
    );
    assert.strictEqual(
      count(".save-or-cancel button.create svg.d-icon-envelope"),
      1,
      "reply button has envelope icon"
    );
  });

  test("edit button when editing a post in a PM", async function (assert) {
    await visit("/t/34");
    await click("article#post_3 button.show-more-actions");
    await click("article#post_3 button.edit");

    assert.strictEqual(
      queryAll(".save-or-cancel button.create").text().trim(),
      I18n.t("composer.save_edit"),
      "save button says Save Edit"
    );
    assert.strictEqual(
      count(".save-or-cancel button.create svg.d-icon-pencil-alt"),
      1,
      "save button has pencil icon"
    );
  });

  test("Shows duplicate_link notice", async function (assert) {
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
    assert.strictEqual(count(".composer-popup"), 1);
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

  test("Does not save invalid draft", async function (assert) {
    this.siteSettings.min_first_post_length = 20;

    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Something");
    await fillIn(".d-editor-input", "Something");
    await click(".save-or-cancel .cancel");
    assert.notOk(exists(".discard-draft-modal .save-draft"));
  });
});

acceptance("Composer - Customizations", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });

  function customComposerAction(composer) {
    return (
      (composer.tags || []).indexOf("monkey") !== -1 &&
      composer.action === CREATE_TOPIC
    );
  }

  needs.hooks.beforeEach(() => {
    withPluginApi("0.8.14", (api) => {
      api.customizeComposerText({
        actionTitle(model) {
          if (customComposerAction(model)) {
            return "custom text";
          }
        },

        saveLabel(model) {
          if (customComposerAction(model)) {
            return "composer.emoji";
          }
        },
      });
    });
  });

  test("Supports text customization", async function (assert) {
    await visit("/");
    await click("#create-topic");
    assert.strictEqual(
      query(".action-title").innerText,
      I18n.t("topic.create_long")
    );
    assert.strictEqual(
      query(".save-or-cancel button").innerText,
      I18n.t("composer.create_topic")
    );
    const tags = selectKit(".mini-tag-chooser");
    await tags.expand();
    await tags.selectRowByValue("monkey");
    assert.strictEqual(query(".action-title").innerText, "custom text");
    assert.strictEqual(
      query(".save-or-cancel button").innerText,
      I18n.t("composer.emoji")
    );
  });
});

// all of these are broken on legacy ember qunit for...some reason. commenting
// until we are fully on ember cli.
acceptance("Composer - Focus Open and Closed", function (needs) {
  needs.user();

  skip("Focusing a composer which is not open with create topic", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const composer = this.container.lookup("controller:composer");
    composer.focusComposer({ fallbackToNewTopic: true });

    await settled();
    assert.strictEqual(
      document.activeElement.classList.contains("d-editor-input"),
      true,
      "composer is opened and focused"
    );
    assert.strictEqual(composer.model.action, Composer.CREATE_TOPIC);
  });

  skip("Focusing a composer which is not open with create topic and append text", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const composer = this.container.lookup("controller:composer");
    composer.focusComposer({
      fallbackToNewTopic: true,
      insertText: "this is appended",
    });

    await settled();
    assert.strictEqual(
      document.activeElement.classList.contains("d-editor-input"),
      true,
      "composer is opened and focused"
    );
    assert.strictEqual(
      query("textarea.d-editor-input").value.trim(),
      "this is appended"
    );
  });

  skip("Focusing a composer which is already open", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const composer = this.container.lookup("controller:composer");
    composer.focusComposer();

    await settled();
    assert.strictEqual(
      document.activeElement.classList.contains("d-editor-input"),
      true,
      "composer is opened and focused"
    );
  });

  skip("Focusing a composer which is already open and append text", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const composer = this.container.lookup("controller:composer");
    composer.focusComposer({ insertText: "this is some appended text" });

    await settled();
    assert.strictEqual(
      document.activeElement.classList.contains("d-editor-input"),
      true,
      "composer is opened and focused"
    );
    assert.strictEqual(
      query("textarea.d-editor-input").value.trim(),
      "this is some appended text"
    );
  });

  skip("Focusing a composer which is not open that has a draft", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggle-minimize");

    const composer = this.container.lookup("controller:composer");
    composer.focusComposer({ insertText: "this is some appended text" });

    await settled();
    assert.strictEqual(
      document.activeElement.classList.contains("d-editor-input"),
      true,
      "composer is opened and focused"
    );
    assert.strictEqual(
      query("textarea.d-editor-input").value.trim(),
      "This is a dirty reply\n\nthis is some appended text"
    );
  });
});
