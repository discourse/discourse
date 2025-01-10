import {
  click,
  currentURL,
  fillIn,
  focus,
  settled,
  triggerEvent,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import LinkLookup from "discourse/lib/link-lookup";
import { withPluginApi } from "discourse/lib/plugin-api";
import { translateModKey } from "discourse/lib/utilities";
import Composer, {
  CREATE_TOPIC,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
import { toggleCheckDraftPopup } from "discourse/services/composer";
import TopicFixtures from "discourse/tests/fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  metaModifier,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";

acceptance("Composer", function (needs) {
  needs.user({
    id: 5,
    username: "kris",
    whisperer: true,
  });
  needs.settings({
    general_category_id: 1,
    default_composer_category: 1,
  });
  needs.site({
    can_tag_topics: true,
    categories: [
      {
        id: 1,
        name: "General",
        slug: "general",
        permission: 1,
        topic_template: null,
      },
      {
        id: 2,
        name: "test too",
        slug: "test-too",
        permission: 1,
        topic_template: "",
      },
    ],
  });
  needs.pretender((server, helper) => {
    server.put("/u/kris.json", () => helper.response({ user: {} }));
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
    server.get("/posts/419", () => {
      return helper.response({ id: 419 });
    });
    server.get("/composer/mentions", () => {
      return helper.response({
        users: [],
        user_reasons: {},
        groups: { staff: { user_count: 30 } },
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });
    server.get("/t/960.json", () => {
      const topicList = cloneJSON(TopicFixtures["/t/9/1.json"]);
      topicList.post_stream.posts[2].post_type = 4;
      return helper.response(topicList);
    });
  });

  needs.hooks.afterEach(() => toggleCheckDraftPopup(false));

  test("Composer is opened", async function (assert) {
    await visit("/");
    await click("#create-topic");
    // Check that the default category is selected
    assert.strictEqual(selectKit(".category-chooser").header().value(), "1");

    assert.strictEqual(
      document.documentElement.style.getPropertyValue("--composer-height"),
      "var(--new-topic-composer-height, 400px)",
      "sets --composer-height to 400px when creating topic"
    );

    await fillIn(
      ".d-editor-input",
      "this is the *content* of a new topic post"
    );
    await click(".toggle-minimize");
    assert.strictEqual(
      document.documentElement.style.getPropertyValue("--composer-height"),
      "40px",
      "sets --composer-height to 40px when composer is minimized to draft mode"
    );

    await click(".toggle-fullscreen");
    assert.strictEqual(
      document.documentElement.style.getPropertyValue("--composer-height"),
      "var(--new-topic-composer-height, 400px)",
      "sets --composer-height back to 400px when composer is opened from draft mode"
    );

    await fillIn(".d-editor-input", "");
    await click(".toggle-minimize");
    assert.strictEqual(
      document.documentElement.style.getPropertyValue("--composer-height"),
      "",
      "removes --composer-height property when composer is closed"
    );
  });

  test("Composer height adjustment", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await triggerEvent(document.querySelector(".grippie"), "mousedown");
    await triggerEvent(document.querySelector(".grippie"), "mousemove");
    await triggerEvent(document.querySelector(".grippie"), "mouseup");
    await visit("/"); // reload page
    await click("#create-topic");

    const expectedHeight = localStorage.getItem(
      "__test_discourse_composerHeight"
    );
    const actualHeight =
      document.documentElement.style.getPropertyValue("--composer-height");

    assert.strictEqual(
      expectedHeight,
      actualHeight,
      "Updated height is persistent"
    );
  });

  test("composer controls", async function (assert) {
    await visit("/");
    assert.dom("#create-topic").exists("the create button is visible");

    await click("#create-topic");
    assert.dom(".d-editor-input").exists("the composer input is visible");
    await focus(".title-input input");
    assert
      .dom(".title-input .popup-tip.good.hide")
      .exists("title errors are hidden by default");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.bad.hide")
      .exists("body errors are hidden by default");

    await click(".toggle-preview");
    assert
      .dom(".d-editor-preview")
      .isNotVisible("clicking the toggle hides the preview");

    await click(".toggle-preview");
    assert
      .dom(".d-editor-preview")
      .isVisible("clicking the toggle shows the preview again");

    await click("#reply-control button.create");
    assert
      .dom(".title-input .popup-tip.bad")
      .exists("shows the empty title error");
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.bad")
      .exists("shows the empty body error");

    await fillIn("#reply-title", "this is my new topic title");
    assert
      .dom(".title-input .popup-tip.good.hide")
      .exists("the title is now good");

    await triggerKeyEvent(
      ".d-editor-textarea-wrapper .popup-tip.bad",
      "keydown",
      "Enter"
    );
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.bad.hide")
      .exists("body error is dismissed via keyboard");

    await fillIn(".d-editor-input", "this is the *content* of a post");
    assert
      .dom(".d-editor-preview")
      .hasHtml(
        "<p>this is the <em>content</em> of a post</p>",
        "previews content"
      );
    assert
      .dom(".d-editor-textarea-wrapper .popup-tip.good")
      .exists("the body is now good");

    const textarea = query("#reply-control .d-editor-input");
    textarea.selectionStart = textarea.value.length;
    textarea.selectionEnd = textarea.value.length;

    await triggerKeyEvent(textarea, "keydown", "B", metaModifier);

    const example = i18n(`composer.bold_text`);
    assert
      .dom("#reply-control .d-editor-input")
      .hasValue(
        `this is the *content* of a post**${example}**`,
        "supports keyboard shortcuts"
      );

    await click("#reply-control a.cancel");
    assert.dom(".d-modal").exists("pops up a confirmation dialog");

    await click(".d-modal__footer .discard-draft");
    assert
      .dom(".d-modal__body")
      .doesNotExist("the confirmation can be cancelled");
  });

  test("Create a topic with server side errors", async function (assert) {
    pretender.post("/posts", function () {
      return response(422, { errors: ["That title has already been taken"] });
    });

    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "this title triggers an error");
    await fillIn(".d-editor-input", "this is the *content* of a post");
    await click("#reply-control button.create");
    assert.dom(".dialog-body").exists("pops up an error message");

    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist("dismisses the error");
    assert.dom(".d-editor-input").exists("the composer input is visible");
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
      "transitions to the newly created topic URL"
    );
  });

  test("Create an enqueued Topic", async function (assert) {
    pretender.post("/posts", function () {
      return response(200, {
        success: true,
        action: "enqueued",
        pending_post: {
          id: 1234,
          raw: "enqueue this content please",
        },
      });
    });

    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Internationalization Localization");
    await fillIn(".d-editor-input", "enqueue this content please");
    await click("#reply-control button.create");
    assert.dom(".d-modal").exists("pops up a modal");
    assert.strictEqual(currentURL(), "/", "doesn't change routes");

    await click(".d-modal__footer button");
    assert.dom(".d-modal").doesNotExist("the modal can be dismissed");
  });

  test("Can display a message and route to a URL", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "This title doesn't matter");
    await fillIn(".d-editor-input", "custom message that is a good length");
    await click("#reply-control button.create");

    assert
      .dom("#dialog-holder .dialog-body")
      .hasText("This is a custom response");
    assert.strictEqual(currentURL(), "/", "doesn't change routes");

    await click(".dialog-footer .btn-primary");
    assert.strictEqual(
      currentURL(),
      "/faq",
      "can navigate to a `route_to` destination"
    );
  });

  test("Create a Reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom('article[data-post-id="12345"]')
      .doesNotExist("the post is not in the DOM");

    await click("#topic-footer-buttons .btn.create");
    assert.dom(".d-editor-input").exists("the composer input is visible");
    assert
      .dom("#reply-title")
      .doesNotExist("there is no title since this is a reply");

    await fillIn(".d-editor-input", "this is the content of my reply");
    await click("#reply-control button.create");
    assert
      .dom(".topic-post:last-of-type .cooked p")
      .hasText("this is the content of my reply");
  });

  test("Replying to the first post in a topic is a topic reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#post_1 .reply.create");
    assert
      .dom(".reply-details a.topic-link")
      .hasText("Internationalization / localization");

    await click("#post_1 .reply.create");
    assert
      .dom(".reply-details a.topic-link")
      .hasText("Internationalization / localization");
  });

  test("Can edit a post after starting a reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .create");
    await fillIn(".d-editor-input", "this is the content of my reply");

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    await click(".d-modal__footer button.keep-editing");
    assert.dom(".discard-draft-modal.modal").doesNotExist();
    assert
      .dom(".d-editor-input")
      .hasValue(
        "this is the content of my reply",
        "composer does not switch when using Keep Editing button"
      );

    await click(".topic-post:nth-of-type(1) button.edit");
    assert.dom(".d-modal__footer button.save-draft").doesNotExist();
    await click(".d-modal__footer button.discard-draft");
    assert.dom(".discard-draft-modal.modal").doesNotExist();

    assert
      .dom(".d-editor-input")
      .hasValue(
        query(".topic-post:nth-of-type(1) .cooked > p").innerText,
        "composer has contents of post to be edited"
      );
  });

  test("Can Keep Editing when replying on a different topic", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .create");
    await fillIn(".d-editor-input", "this is the content of my reply");

    await visit("/t/this-is-a-test-topic/9");
    await click("#topic-footer-buttons .create");
    assert.dom(".discard-draft-modal.modal").exists();

    await click(".d-modal__footer button.keep-editing");
    assert.dom(".discard-draft-modal.modal").doesNotExist();

    assert
      .dom(".d-editor-input")
      .hasValue(
        "this is the content of my reply",
        "composer does not switch when using Keep Editing button"
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
    assert.dom(".reply-where-modal").exists("pops up a modal");

    await click(".btn-reply-here");
    assert
      .dom(".topic-post:last-of-type .cooked p")
      .hasText(
        "If you use gettext format you could leverage Launchpad translations and the community behind it."
      );
  });

  test("Discard draft modal works when switching topics", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", "this is the content of the first reply");

    await visit("/t/this-is-a-test-topic/9");
    assert.true(
      currentURL().startsWith("/t/this-is-a-test-topic/9"),
      "moves to second topic"
    );
    await click("#topic-footer-buttons .btn.create");
    assert
      .dom(".discard-draft-modal.modal")
      .exists("pops up the discard drafts modal");

    await click(".d-modal__footer button.keep-editing");

    assert.dom(".discard-draft-modal.modal").doesNotExist("hides modal");
    await click("#topic-footer-buttons .btn.create");
    assert.dom(".discard-draft-modal.modal").exists("pops up the modal again");

    await click(".d-modal__footer button.discard-draft");

    assert
      .dom(".d-editor-input")
      .hasNoValue("discards draft and reset composer textarea");
  });

  test("Create an enqueued Reply", async function (assert) {
    pretender.post("/posts", function () {
      return response(200, {
        success: true,
        action: "enqueued",
        pending_post: {
          id: 1234,
          raw: "enqueue this content please",
        },
      });
    });

    await visit("/t/internationalization-localization/280");
    assert.dom(".pending-posts .reviewable-item").doesNotExist();

    await click("#topic-footer-buttons .btn.create");
    assert.dom(".d-editor-input").exists("the composer input is visible");
    assert
      .dom("#reply-title")
      .doesNotExist("there is no title since this is a reply");

    await fillIn(".d-editor-input", "enqueue this content please");
    await click("#reply-control button.create");
    assert
      .dom(".topic-post:last-of-type .cooked p")
      .doesNotIncludeText(
        "enqueue this content please",
        "doesn't insert the post"
      );
    assert.dom(".d-modal").exists("pops up a modal");

    await click(".d-modal__footer button");
    assert.dom(".d-modal").doesNotExist("the modal can be dismissed");
    assert.dom(".pending-posts .reviewable-item").exists();
  });

  test("Edit the first post", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom(".topic-post:nth-of-type(1) .post-info.edits")
      .doesNotExist("has no edits icon at first");

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^Any plans to support/,
        "populates the input with the post text"
      );

    await fillIn(".d-editor-input", "This is the new text for the post");
    await fillIn("#reply-title", "This is the new text for the title");
    await click("#reply-control button.create");
    assert.dom(".d-editor-input").doesNotExist("closes the composer");
    assert
      .dom(".topic-post:nth-of-type(1) .post-info.edits")
      .exists("has the edits icon");
    assert
      .dom("#topic-title h1")
      .includesText(
        "This is the new text for the title",
        "shows the new title"
      );
    assert
      .dom(".topic-post:nth-of-type(1) .cooked")
      .includesText("This is the new text for the post", "updates the post");
  });

  test("Editing a post stages new content", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post button.show-more-actions");
    await click(".topic-post button.edit");

    await fillIn(".d-editor-input", "will return empty json");
    await fillIn("#reply-title", "This is the new text for the title");

    pretender.put("/posts/:post_id", async () => {
      // at this point, request is in flight, so post is staged
      assert.dom(".topic-post").exists();
      assert.dom(".topic-post").hasClass("staged");
      assert
        .dom(".topic-post.staged .cooked")
        .hasText("will return empty json");

      return response(200, {});
    });

    await click("#reply-control button.create");

    await visit("/t/internationalization-localization/280");
    assert.dom(".topic-post.staged").doesNotExist();
  });

  test("Composer can switch between edits", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the first post\./,
        "populates the input with the post text"
      );
    await click(".topic-post:nth-of-type(2) button.edit");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the second post\./,
        "populates the input with the post text"
      );
  });

  test("Composer with dirty edit can toggle to another edit", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".topic-post:nth-of-type(2) button.edit");
    assert
      .dom(".discard-draft-modal.modal")
      .exists("pops up a confirmation dialog");

    await click(".d-modal__footer button.discard-draft");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the second post\./,
        "populates the input with the post text"
      );
  });

  test("Composer can toggle between edit and reply on the OP", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the first post\./,
        "populates the input with the post text"
      );

    await click(".topic-post:nth-of-type(1) button.reply");
    assert.dom(".d-editor-input").hasNoValue("clears the composer input");

    await click(".topic-post:nth-of-type(1) button.edit");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the first post\./,
        "populates the input with the post text"
      );
  });

  test("Composer can toggle between edit and reply on a reply", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(2) button.edit");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the second post\./,
        "populates the input with the post text"
      );

    await click(".topic-post:nth-of-type(2) button.reply");
    assert.dom(".d-editor-input").hasNoValue("clears the composer input");

    await click(".topic-post:nth-of-type(2) button.edit");
    assert.true(
      query(".d-editor-input").value.startsWith("This is the second post."),
      "populates the input with the post text"
    );
  });

  test("Composer can toggle whispers when whisperer user", async function (assert) {
    const menu = selectKit(".toolbar-popup-menu-options");

    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    await menu.expand();
    await menu.selectRowByName("toggle-whisper");

    assert
      .dom(".composer-actions svg.d-icon-far-eye-slash")
      .exists("sets the post type to whisper");

    await menu.expand();
    await menu.selectRowByName("toggle-whisper");

    assert
      .dom(".composer-actions svg.d-icon-far-eye-slash")
      .doesNotExist("removes the whisper mode");

    await menu.expand();
    await menu.selectRowByName("toggle-whisper");

    await click(".toggle-fullscreen");

    await menu.expand();

    assert.true(
      menu.rowByName("toggle-whisper").exists(),
      "whisper toggling is still present when going fullscreen"
    );
  });

  test("Composer can toggle layouts (open, fullscreen and draft)", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    assert.dom("#reply-control.open").exists("starts in open state by default");

    await click(".toggle-fullscreen");

    assert
      .dom("#reply-control.fullscreen")
      .exists("expands composer to full screen");

    assert
      .dom(".composer-fullscreen-prompt")
      .exists("the exit fullscreen prompt is visible");

    await click(".toggle-fullscreen");

    assert
      .dom("#reply-control.open")
      .exists("collapses composer to regular size");

    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggler");

    assert
      .dom("#reply-control.draft")
      .exists("collapses composer to draft bar");

    await click(".toggle-fullscreen");

    assert
      .dom("#reply-control.open")
      .exists("from draft, it expands composer back to open state");
  });

  test("Composer fullscreen submit button", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    assert.dom("#reply-control.open").exists("starts in open state by default");

    await click(".toggle-fullscreen");

    assert
      .dom("#reply-control button.create")
      .exists("shows composer submit button in fullscreen");

    await fillIn(".d-editor-input", "too short");
    await click("#reply-control button.create");

    assert
      .dom("#reply-control.open")
      .exists("goes back to open state if there's errors");
  });

  test("Composer can toggle between reply and createTopic", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post:nth-of-type(1) button.reply");

    await selectKit(".toolbar-popup-menu-options").expand();

    await selectKit(".toolbar-popup-menu-options").selectRowByName(
      "toggle-whisper"
    );

    assert
      .dom(".composer-actions svg.d-icon-far-eye-slash")
      .exists("sets the post type to whisper");

    await visit("/");
    assert.dom("#create-topic").exists("the create topic button is visible");

    await click("#create-topic");
    assert
      .dom(".reply-details .whisper .d-icon-far-eye-slash")
      .doesNotExist("should reset the state of the composer's model");

    await selectKit(".toolbar-popup-menu-options").expand();
    await selectKit(".toolbar-popup-menu-options").selectRowByName(
      "toggle-invisible"
    );

    assert
      .dom(".reply-details .unlist")
      .includesText(i18n("composer.unlist"), "sets the topic to unlisted");

    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    assert
      .dom(".reply-details .whisper")
      .doesNotExist("should reset the state of the composer's model");
  });

  test("Composer can toggle whisper when switching from reply to whisper to reply to topic", async function (assert) {
    await visit("/t/topic-with-whisper/960");

    await click(".topic-post:nth-of-type(3) button.reply");
    await click(".reply-details summary div");
    assert
      .dom('.reply-details li[data-value="toggle_whisper"]')
      .doesNotExist("toggle whisper is not available when reply to whisper");
    await click('.reply-details li[data-value="reply_to_topic"]');
    await click(".reply-details summary div");
    assert
      .dom('.reply-details li[data-value="toggle_whisper"]')
      .exists("toggle whisper is available when reply to topic");
  });

  test("Composer can toggle whisper when clicking reply to topic after reply to whisper", async function (assert) {
    await visit("/t/topic-with-whisper/960");

    await click(".topic-post:nth-of-type(3) button.reply");
    await click("#reply-control .save-or-cancel a.cancel");
    await click(".topic-footer-main-buttons button.create");
    await click(".reply-details summary div");
    assert
      .dom('.reply-details li[data-value="toggle_whisper"]')
      .exists("toggle whisper is available when reply to topic");
  });

  test("Composer draft with dirty reply can toggle to edit", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggler");
    await click(".topic-post:nth-of-type(2) button.edit");
    assert
      .dom(".discard-draft-modal.modal")
      .exists("pops up a confirmation dialog");
    assert.dom(".d-modal__footer button.save-draft").doesNotExist();
    assert
      .dom(".d-modal__footer button.keep-editing")
      .hasText(
        i18n("post.cancel_composer.keep_editing"),
        "has keep editing button"
      );
    await click(".d-modal__footer button.discard-draft");
    assert
      .dom(".d-editor-input")
      .hasValue(
        /^This is the second post\./,
        "populates the input with the post text"
      );
  });

  test("Composer draft can switch to draft in new context without destroying current draft", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.reply");
    await fillIn(".d-editor-input", "This is a dirty reply");

    await click("#site-logo");
    await click("#create-topic");

    assert
      .dom(".discard-draft-modal.modal")
      .exists("pops up a confirmation dialog");
    assert
      .dom(".d-modal__footer button.save-draft")
      .hasText(
        i18n("post.cancel_composer.save_draft"),
        "has save draft button"
      );
    assert
      .dom(".d-modal__footer button.keep-editing")
      .hasText(
        i18n("post.cancel_composer.keep_editing"),
        "has keep editing button"
      );

    await click(".d-modal__footer button.save-draft");
    assert.dom(".d-editor-input").hasNoValue("clears the composer input");
  });

  test("Checks for existing draft", async function (assert) {
    toggleCheckDraftPopup(true);

    await visit("/t/internationalization-localization/280");

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    assert.dom(".dialog-body").hasText(i18n("drafts.abandon.confirm"));

    await click(".dialog-footer .btn-resume-editing");
  });

  test("Can switch states without abandon popup", async function (assert) {
    toggleCheckDraftPopup(true);

    await visit("/t/internationalization-localization/280");

    const longText = "a".repeat(256);

    sinon.stub(Draft, "get").resolves({
      draft: null,
      draft_sequence: 0,
    });

    await click(".btn-primary.create.btn");

    await fillIn(".d-editor-input", longText);

    assert
      .dom('.action-title a[href="/t/internationalization-localization/280"]')
      .exists("the mode should be: reply to post");

    await click("article#post_3 button.reply");

    const composerActions = selectKit(".composer-actions");
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_new_topic");

    assert.dom(".d-modal__body").doesNotExist("abandon popup shouldn't come");

    assert
      .dom(".d-editor-input")
      .includesValue(longText, "entered text should still be there");

    assert
      .dom('.action-title a[href="/t/internationalization-localization/280"]')
      .doesNotExist("mode should have changed");
  });

  test("Loading draft also replaces the recipients", async function (assert) {
    toggleCheckDraftPopup(true);

    sinon.stub(Draft, "get").resolves({
      draft:
        '{"reply":"hello","action":"privateMessage","title":"hello","categoryId":null,"archetypeId":"private_message","metaData":null,"recipients":"codinghorror","composerTime":9159,"typingTime":2500}',
      draft_sequence: 0,
    });

    await visit("/u/charlie");
    await click("button.compose-pm");
    await click(".dialog-footer .btn-resume-editing");

    const privateMessageUsers = selectKit("#private-message-users");
    assert.strictEqual(privateMessageUsers.header().value(), "codinghorror");
  });

  test("Loads tags and category from draft payload", async function (assert) {
    updateCurrentUser({ has_topic_draft: true });

    sinon.stub(Draft, "get").resolves({
      draft:
        '{"reply":"Hey there","action":"createTopic","title":"Draft topic","categoryId":2,"tags":["fun", "xmark"],"archetypeId":"regular","metaData":null,"composerTime":25269,"typingTime":8100}',
      draft_sequence: 0,
      draft_key: NEW_TOPIC_KEY,
    });

    await visit("/latest");
    assert.dom("#create-topic").hasText(i18n("topic.create"));

    await click("#create-topic");
    assert.strictEqual(selectKit(".category-chooser").header().value(), "2");
    assert.strictEqual(
      selectKit(".mini-tag-chooser").header().value(),
      "fun,xmark"
    );
  });

  test("Deleting the text content of the first post in a private message", async function (assert) {
    await visit("/t/34");

    await click("#post_1 .d-icon-ellipsis");
    await click("#post_1 .d-icon-pencil");
    await fillIn(".d-editor-input", "");

    assert
      .dom(".d-editor-container textarea")
      .hasAttribute(
        "placeholder",
        i18n("composer.reply_placeholder"),
        "should not block because of missing category"
      );
  });

  test("reply button has envelope icon when replying to private message", async function (assert) {
    await visit("/t/34");
    await click("article#post_3 button.reply");
    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.create_pm"), "reply button says Message");
    assert
      .dom(".save-or-cancel button.create svg.d-icon-envelope")
      .exists("reply button has envelope icon");
  });

  test("edit button when editing a post in a PM", async function (assert) {
    await visit("/t/34");
    await click("article#post_3 button.show-more-actions");
    await click("article#post_3 button.edit");

    assert
      .dom(".save-or-cancel button.create")
      .hasText(i18n("composer.save_edit"), "save button says Save Edit");
    assert
      .dom(".save-or-cancel button.create svg.d-icon-pencil")
      .exists("save button has pencil icon");
  });

  test("Shows duplicate_link notice", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");

    this.container.lookup("service:composer").set(
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
    assert.dom(".composer-popup").doesNotExist();

    await fillIn(".d-editor-input", "[quote][](https://github.com)[/quote]");
    assert.dom(".composer-popup").doesNotExist();

    await fillIn(".d-editor-input", "[](https://github.com)");
    assert.dom(".composer-popup").exists();
  });

  test("Shows the 'group_mentioned' notice", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");

    await fillIn(".d-editor-input", "[quote]\n@staff\n[/quote]");
    assert
      .dom(".composer-popup")
      .doesNotExist("Doesn't show the 'group_mentioned' notice in a quote");

    await fillIn(".d-editor-input", "@staff");
    assert.dom(".composer-popup").exists("shows the 'group_mentioned' notice");
  });

  test("Does not save invalid draft", async function (assert) {
    this.siteSettings.min_first_post_length = 20;

    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Something");
    await fillIn(".d-editor-input", "Something");
    await click(".save-or-cancel .cancel");
    assert.dom(".discard-draft-modal .save-draft").doesNotExist();
  });

  test("Saves drafts that only contain quotes", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");

    await fillIn(".d-editor-input", "[quote]some quote[/quote]");

    await click(".save-or-cancel .cancel");
    assert.dom(".discard-draft-modal .save-draft").exists();
  });

  test("Discard drafts modal can be dismissed via keyboard", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .create");

    await fillIn(".d-editor-input", "[quote]some quote[/quote]");

    await click(".save-or-cancel .cancel");
    assert.dom(".discard-draft-modal .save-draft").exists();

    await triggerKeyEvent(
      ".discard-draft-modal .save-draft",
      "keydown",
      "Escape"
    );

    assert.dom(".discard-draft-modal").doesNotExist();

    assert
      .dom(".d-editor-input")
      .hasValue(
        "[quote]some quote[/quote]",
        "composer textarea is not cleared"
      );
  });
});

acceptance("Composer - Customizations", function (needs) {
  needs.user();
  needs.site({ can_tag_topics: true });

  function customComposerAction(composer) {
    return (
      (composer.tags || []).includes("monkey") &&
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
    assert.dom(".action-title").hasText(i18n("topic.create_long"));
    assert.dom(".save-or-cancel button").hasText(i18n("composer.create_topic"));
    const tags = selectKit(".mini-tag-chooser");
    await tags.expand();
    await tags.selectRowByValue("monkey");
    assert.dom(".action-title").hasText("custom text");
    assert.dom(".save-or-cancel button").hasText(i18n("composer.emoji"));
  });
});

acceptance("Composer - Error Extensibility", function (needs) {
  needs.user();
  needs.settings({
    general_category_id: 1,
    default_composer_category: 1,
  });

  needs.hooks.beforeEach(() => {
    withPluginApi("1.5.0", (api) => {
      api.addComposerSaveErrorCallback((error) => {
        if (error.match(/PLUGIN_XYZ ERROR/)) {
          // handle error
          return true;
        }
        return false;
      });
    });
  });

  test("Create a topic with server side errors handled by a plugin", async function (assert) {
    pretender.post("/posts", function () {
      return response(422, { errors: ["PLUGIN_XYZ ERROR"] });
    });

    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "this title triggers an error");
    await fillIn(".d-editor-input", "this is the *content* of a post");
    await click("#reply-control button.create");
    assert.dom(".dialog-body").doesNotExist("does not pop up an error message");
  });

  test("Create a topic with server side errors not handled by a plugin", async function (assert) {
    pretender.post("/posts", function () {
      return response(422, { errors: ["PLUGIN_ABC ERROR"] });
    });

    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "this title triggers an error");
    await fillIn(".d-editor-input", "this is the *content* of a post");
    await click("#reply-control button.create");
    assert.dom(".dialog-body").exists("pops up an error message");
    assert
      .dom(".dialog-body")
      .hasText(/PLUGIN_ABC ERROR/, "contains the server side error text");
    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist("dismisses the error");
    assert.dom(".d-editor-input").exists("the composer input is visible");
  });
});

acceptance("Composer - Focus Open and Closed", function (needs) {
  needs.user();
  needs.settings({ allow_uncategorized_topics: true });

  test("Focusing a composer which is not open with create topic", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const composer = this.container.lookup("service:composer");
    await composer.focusComposer({ fallbackToNewTopic: true });

    await settled();
    assert.dom(".d-editor-input").isFocused("composer is open and focused");
    assert.strictEqual(composer.model.action, Composer.CREATE_TOPIC);
  });

  test("Focusing a composer which is not open with create topic and append text", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const composer = this.container.lookup("service:composer");
    await composer.focusComposer({
      fallbackToNewTopic: true,
      insertText: "this is appended",
    });

    await settled();
    assert.dom(".d-editor-input").isFocused("composer is open and focused");
    assert.dom("textarea.d-editor-input").hasValue("this is appended");
  });

  test("Focusing a composer which is already open", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const composer = this.container.lookup("service:composer");
    await composer.focusComposer();

    await settled();
    assert.dom(".d-editor-input").isFocused("composer is open and focused");
  });

  test("Focusing a composer which is already open and append text", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const composer = this.container.lookup("service:composer");
    await composer.focusComposer({ insertText: "this is some appended text" });

    await settled();
    assert.dom(".d-editor-input").isFocused("composer is open and focused");
    assert
      .dom("textarea.d-editor-input")
      .hasValue("this is some appended text");
  });

  test("Focusing a composer which is not open that has a draft", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post:nth-of-type(1) button.edit");
    await fillIn(".d-editor-input", "This is a dirty reply");
    await click(".toggle-minimize");

    const composer = this.container.lookup("service:composer");
    await composer.focusComposer({ insertText: "this is some appended text" });

    await settled();
    assert.dom(".d-editor-input").isFocused("composer is open and focused");
    assert
      .dom("textarea.d-editor-input")
      .hasValue("This is a dirty reply\n\nthis is some appended text");
  });
});

// Default Composer Category tests
acceptance("Composer - Default category", function (needs) {
  needs.user();
  needs.settings({
    general_category_id: 1,
    default_composer_category: 2,
  });
  needs.site({
    categories: [
      {
        id: 1,
        name: "General",
        slug: "general",
        permission: 1,
        topic_template: null,
      },
      {
        id: 2,
        name: "test too",
        slug: "test-too",
        permission: 1,
        topic_template: null,
      },
    ],
  });

  test("Default category is selected over general category", async function (assert) {
    await visit("/");
    await click("#create-topic");
    assert.strictEqual(selectKit(".category-chooser").header().value(), "2");
    assert.strictEqual(
      selectKit(".category-chooser").header().name(),
      "test too"
    );
  });
});

acceptance("Composer - Uncategorized category", function (needs) {
  needs.user();
  needs.settings({
    general_category_id: -1, // For sites that never had this seeded
    default_composer_category: -1, // For sites that never had this seeded
    allow_uncategorized_topics: true,
  });
  needs.site({
    categories: [
      {
        id: 1,
        name: "General",
        slug: "general",
        permission: 1,
        topic_template: null,
      },
      {
        id: 2,
        name: "test too",
        slug: "test-too",
        permission: 1,
        topic_template: null,
      },
    ],
  });

  test("Uncategorized category is selected", async function (assert) {
    await visit("/");
    await click("#create-topic");
    assert.strictEqual(selectKit(".category-chooser").header().value(), null);
  });
});

acceptance("Composer - default category not set", function (needs) {
  needs.user();
  needs.settings({
    default_composer_category: "",
  });
  needs.site({
    categories: [
      {
        id: 1,
        name: "General",
        slug: "general",
        permission: 1,
        topic_template: null,
      },
      {
        id: 2,
        name: "test too",
        slug: "test-too",
        permission: 1,
        topic_template: null,
      },
    ],
  });

  test("Nothing is selected", async function (assert) {
    await visit("/");
    await click("#create-topic");
    assert.strictEqual(selectKit(".category-chooser").header().value(), null);
    assert.strictEqual(
      selectKit(".category-chooser").header().name(),
      "category&hellip;"
    );
  });
});
// END: Default Composer Category tests

acceptance("composer buttons API", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
  });

  test("buttons can support a shortcut", async function (assert) {
    withPluginApi("0", (api) => {
      api.addComposerToolbarPopupMenuOption({
        action: (toolbarEvent) => {
          toolbarEvent.applySurround("**", "**");
        },
        shortcut: "alt+b",
        icon: "far-bold",
        name: "bold",
        title: "some_title",
        label: "some_label",

        condition: () => {
          return true;
        },
      });
    });

    await visit("/t/internationalization-localization/280");
    await click(".post-controls button.reply");
    await fillIn(".d-editor-input", "hello the world");

    const editor = document.querySelector(".d-editor-input");
    editor.setSelectionRange(6, 9); // select the text input in the composer

    await triggerKeyEvent(".d-editor-input", "keydown", "B", {
      altKey: true,
      ...metaModifier,
    });

    assert
      .dom(".d-editor-input")
      .hasValue("hello **the** world", "adds the bold");

    const dropdown = selectKit(".toolbar-popup-menu-options");
    await dropdown.expand();

    const row = dropdown.rowByName("bold").el();
    assert
      .dom(row)
      .hasAttribute(
        "title",
        i18n("some_title") +
          ` (${translateModKey(PLATFORM_KEY_MODIFIER + "+alt+b")})`,
        "shows the title with shortcut"
      );
    assert
      .dom(row)
      .hasText(
        i18n("some_label") +
          ` ${translateModKey(PLATFORM_KEY_MODIFIER + "+alt+b")}`,
        "shows the label with shortcut"
      );
  });

  test("buttons can support a shortcut that triggers a custom action", async function (assert) {
    withPluginApi("1.37.1", (api) => {
      api.onToolbarCreate((toolbar) => {
        toolbar.addButton({
          id: "smile",
          group: "extras",
          icon: "far-face-smile",
          shortcut: "ALT+S",
          shortcutAction: (toolbarEvent) => {
            toolbarEvent.addText(":smile: from keyboard");
          },
          sendAction: (event) => {
            event.addText(":smile: from click");
          },
        });
      });
    });

    await visit("/t/internationalization-localization/280");
    await click(".post-controls button.reply");

    const editor = document.querySelector(".d-editor-input");
    await triggerKeyEvent(".d-editor-input", "keydown", "S", {
      altKey: true,
      ...metaModifier,
    });

    assert.dom(editor).hasValue(":smile: from keyboard");
  });

  test("buttons can be added conditionally", async function (assert) {
    withPluginApi("0", (api) => {
      api.addComposerToolbarPopupMenuOption({
        action: (toolbarEvent) => {
          toolbarEvent.applySurround("**", "**");
        },
        icon: "far-bold",
        label: "some_label",
        condition: (composer) => {
          return composer.model.creatingTopic;
        },
      });
    });

    await visit("/t/internationalization-localization/280");

    await click(".post-controls button.reply");
    assert.dom(".d-editor-input").exists("the composer input is visible");

    const expectedName = "[en.some_label]";
    const dropdown = selectKit(".toolbar-popup-menu-options");
    await dropdown.expand();

    assert.false(
      dropdown.rowByName(expectedName).exists(),
      "custom button is not displayed for reply"
    );

    await visit("/latest");
    await click("#create-topic");

    await dropdown.expand();
    assert.true(
      dropdown.rowByName(expectedName).exists(),
      "custom button is displayed for new topic"
    );
  });
});
