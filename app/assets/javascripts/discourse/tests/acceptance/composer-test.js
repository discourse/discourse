import {
  click,
  currentURL,
  fillIn,
  find,
  focus,
  settled,
  triggerEvent,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import LinkLookup from "discourse/lib/link-lookup";
import { cloneJSON } from "discourse/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import { translateModKey } from "discourse/lib/utilities";
import Composer, { CREATE_TOPIC } from "discourse/models/composer";
import Draft from "discourse/models/draft";
import TopicFixtures from "discourse/tests/fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  metaModifier,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Composer (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user({
        id: 5,
        username: "kris",
        whisperer: true,
      });
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
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

      test("Composer is opened", async function (assert) {
        await visit("/");
        await click("#create-topic");
        // Check that the default category is selected
        assert.strictEqual(
          selectKit(".category-chooser").header().value(),
          "1"
        );

        assert.strictEqual(
          document.documentElement.style.getPropertyValue("--composer-height"),
          "var(--new-topic-composer-height, 400px)",
          "sets --composer-height to 400px when creating topic"
        );

        await click(".toggle-minimize");
        assert.strictEqual(
          document.documentElement.style.getPropertyValue("--composer-height"),
          "40px",
          "sets --composer-height to 40px when composer is minimized without content"
        );

        await click(".toggle-fullscreen");
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
        await click("#reply-control .discard-button");
        assert.strictEqual(
          document.documentElement.style.getPropertyValue("--composer-height"),
          "",
          "removes --composer-height property when composer is closed"
        );
      });

      test("Composer height adjustment", async function (assert) {
        await visit("/");
        await click("#create-topic");
        await triggerEvent(".grippie", "mousedown");
        await triggerEvent(".grippie", "mousemove");
        await triggerEvent(".grippie", "mouseup");
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

        const textarea = find("#reply-control .d-editor-input");
        textarea.selectionStart = textarea.value.length;
        textarea.selectionEnd = textarea.value.length;

        await triggerKeyEvent(textarea, "keydown", "B", metaModifier);

        assert
          .dom("#reply-control .d-editor-input")
          .hasValue(
            `this is the *content* of a post**${i18n("composer.bold_text")}**`,
            "supports keyboard shortcuts"
          );

        await click("#reply-control .discard-button");
        assert.dom(".d-modal").exists("pops up a confirmation dialog");

        await click(".d-modal__footer .discard-draft");
        assert
          .dom(".d-modal__body")
          .doesNotExist("the confirmation can be cancelled");
      });

      test("Create a topic with server side errors", async function (assert) {
        pretender.post("/posts", function () {
          return response(422, {
            errors: ["That title has already been taken"],
          });
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
          .dom(".topic-post:nth-last-child(1 of .topic-post) .cooked p")
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

        await click(
          ".topic-post[data-post-number='1'] button.show-more-actions"
        );
        await click(".topic-post[data-post-number='1'] button.edit");

        await click(".d-modal__footer button.keep-editing");
        assert.dom(".discard-draft-modal.modal").doesNotExist();
        assert
          .dom(".d-editor-input")
          .hasValue(
            "this is the content of my reply",
            "composer does not switch when using Keep Editing button"
          );

        await click(".topic-post[data-post-number='1'] button.edit");
        assert.dom(".d-modal__footer button.save-draft").doesNotExist();
        await click(".d-modal__footer button.discard-draft");
        assert.dom(".discard-draft-modal.modal").doesNotExist();

        assert
          .dom(".d-editor-input")
          .hasValue(
            find(".topic-post[data-post-number='1'] .cooked > p").innerText,
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
        assert
          .dom(".topic-title")
          .exists({ count: 2 }, "it renders the two topics");
        assert
          .dom(".btn-reply-where:nth-of-type(1) .badge-category__name")
          .hasText("test too", "it renders the category name");
        assert
          .dom(".btn-reply-where:nth-of-type(2) .discourse-tags")
          .hasText("foo", "it renders the tags");

        await click(".btn-reply-here");

        assert
          .dom(".topic-post:nth-last-child(1 of .topic-post) .cooked p")
          .hasText(
            "If you use gettext format you could leverage Launchpad translations and the community behind it."
          );
      });

      test("Discard draft modal works when switching topics", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click("#topic-footer-buttons .btn.create");
        await fillIn(
          ".d-editor-input",
          "this is the content of the first reply"
        );

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
        assert
          .dom(".discard-draft-modal.modal")
          .exists("pops up the modal again");

        await click(".d-modal__footer button.discard-draft");

        assert
          .dom(".d-editor-input")
          .hasValue(
            "This is a draft of the first post",
            "loads the existing draft"
          );
      });

      test("Loads draft in composer when clicking reply on a topic with existing draft", async function (assert) {
        await visit("/t/internationalization-localization/280");

        await click("#topic-footer-buttons .btn.create");

        assert
          .dom(".d-editor-input")
          .hasValue("This is a draft of the first post");
      });

      test("Autosaves drafts after clicking keep editing or escaping modal", async function (assert) {
        pretender.post("/drafts.json", function () {
          assert.step("saveDraft");
          return response(200, {});
        });
        pretender.get("/drafts/topic_280.json", function () {
          return response(200, { draft: null });
        });

        await visit("/t/internationalization-localization/280");

        await click("#topic-footer-buttons .btn.create");

        await fillIn(".d-editor-input", "this is draft content of the reply");

        assert.verifySteps(["saveDraft"], "first draft is auto saved");

        await click("#reply-control .discard-button");

        assert
          .dom(".discard-draft-modal.modal")
          .exists("pops up the discard drafts modal");

        await click(".d-modal__footer button.keep-editing");
        assert.dom(".discard-draft-modal.modal").doesNotExist("hides modal");

        assert
          .dom(".d-editor-input")
          .hasValue(
            "this is draft content of the reply",
            "composer has the content of the first draft"
          );

        await fillIn(
          ".d-editor-input",
          "this is the first update to the draft content",
          "update content in the composer"
        );

        assert.verifySteps(["saveDraft"], "second draft is saved");

        await click("#reply-control .discard-button");

        assert
          .dom(".discard-draft-modal.modal")
          .exists("pops up the discard drafts modal");

        await triggerKeyEvent(
          ".discard-draft-modal .save-draft",
          "keydown",
          "Escape"
        );
        assert.dom(".discard-draft-modal.modal").doesNotExist("hides modal");

        await fillIn(
          ".d-editor-input",
          "this is the second update to the draft content",
          "update content in the composer"
        );

        assert.verifySteps(["saveDraft"], "third draft is saved");

        await click("#reply-control button.create");

        assert
          .dom(".topic-post:nth-last-child(1 of .topic-post) .cooked p")
          .hasText("this is the second update to the draft content");
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
          .dom(".topic-post:nth-last-child(1 of .topic-post) .cooked p")
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
          .dom(".topic-post[data-post-number='1'] .post-info.edits")
          .doesNotExist("has no edits icon at first");

        await click(
          ".topic-post[data-post-number='1'] button.show-more-actions"
        );
        await click(".topic-post[data-post-number='1'] button.edit");
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
          .dom(".topic-post[data-post-number='1'] .post-info.edits")
          .exists("has the edits icon");
        assert
          .dom("#topic-title h1")
          .includesText(
            "This is the new text for the title",
            "shows the new title"
          );
        assert
          .dom(".topic-post[data-post-number='1'] .cooked")
          .includesText(
            "This is the new text for the post",
            "updates the post"
          );
      });

      test("Editing a post stages new content", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click(".topic-post button.show-more-actions");
        await click(".topic-post button.edit");

        await fillIn(".d-editor-input", "will return empty json");
        await fillIn("#reply-title", "This is the new text for the title");

        const done = assert.async();

        pretender.put("/posts/:post_id", async () => {
          // at this point, request is in flight, so post is staged
          await waitFor(".topic-post.staged");

          assert.dom(".topic-post.staged").exists();
          assert
            .dom(".topic-post.staged .cooked")
            .hasText("will return empty json");

          done();

          return response(200, {});
        });

        await click("#reply-control button.create");

        await visit("/t/internationalization-localization/280");
        assert.dom(".topic-post.staged").doesNotExist();
      });

      test("Composer can switch between edits", async function (assert) {
        await visit("/t/this-is-a-test-topic/9");

        await click(".topic-post[data-post-number='1'] button.edit");
        assert
          .dom(".d-editor-input")
          .hasValue(
            /^This is the first post\./,
            "populates the input with the post text"
          );
        await click(".topic-post[data-post-number='2'] button.edit");
        assert
          .dom(".d-editor-input")
          .hasValue(
            /^This is the second post\./,
            "populates the input with the post text"
          );
      });

      test("Composer with dirty edit can toggle to another edit", async function (assert) {
        await visit("/t/this-is-a-test-topic/9");

        await click(".topic-post[data-post-number='1'] button.edit");
        await fillIn(".d-editor-input", "This is a dirty reply");
        await click(".topic-post[data-post-number='2'] button.edit");
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
        await visit("/t/this-is-a-test-topic/54081");

        await click(".topic-post[data-post-number='1'] button.edit");
        assert
          .dom(".d-editor-input")
          .hasValue(
            /^This is the first post\./,
            "populates the input with the post text"
          );

        await click(".topic-post[data-post-number='1'] button.reply");
        assert.dom(".d-editor-input").hasNoValue("clears the composer input");

        await click(".topic-post[data-post-number='1'] button.edit");
        assert
          .dom(".d-editor-input")
          .hasValue(
            /^This is the first post\./,
            "populates the input with the post text"
          );
      });

      test("Composer can toggle between edit and reply on a reply", async function (assert) {
        await visit("/t/this-is-a-test-topic/54081");

        await click(".topic-post[data-post-number='2'] button.edit");
        assert
          .dom(".d-editor-input")
          .hasValue(
            /^This is the second post\./,
            "populates the input with the post text"
          );

        await click(".topic-post[data-post-number='2'] button.reply");
        assert.dom(".d-editor-input").hasNoValue("clears the composer input");

        await click(".topic-post[data-post-number='2'] button.edit");
        assert
          .dom(".d-editor-input")
          .hasValue(
            /^This is the second post\./,
            "populates the input with the post text"
          );
      });

      test("Composer can toggle whispers when whisperer user", async function (assert) {
        const menu = selectKit(".composer-actions");

        await visit("/t/this-is-a-test-topic/9");
        await click(".topic-post[data-post-number='1'] button.reply");

        await menu.expand();
        await menu.selectRowByValue("toggle_whisper");

        assert
          .dom(".composer-actions svg.d-icon-far-eye-slash")
          .exists("sets the post type to whisper");

        await menu.expand();
        await menu.selectRowByValue("toggle_whisper");

        assert
          .dom(".composer-actions svg.d-icon-far-eye-slash")
          .doesNotExist("removes the whisper mode");
      });

      test("Composer can toggle layouts (open, fullscreen and draft)", async function (assert) {
        await visit("/t/this-is-a-test-topic/9");
        await click(".topic-post[data-post-number='1'] button.reply");

        assert
          .dom("#reply-control.open")
          .isVisible("starts in open state by default");

        await click(".toggle-fullscreen");

        assert
          .dom("#reply-control.fullscreen")
          .isVisible("expands composer to full screen");

        assert
          .dom(".composer-fullscreen-prompt")
          .isVisible("the fullscreen prompt is visible");

        await click(".toggle-fullscreen");

        assert
          .dom("#reply-control.open")
          .isVisible("collapses composer to regular size");

        await fillIn(".d-editor-input", "This is a dirty reply");
        await click(".toggler");

        assert
          .dom("#reply-control.draft")
          .isVisible("collapses composer to draft bar");

        await click(".toggle-fullscreen");

        assert
          .dom("#reply-control.open")
          .isVisible("from draft, it expands composer back to open state");
      });

      test("Composer fullscreen submit button", async function (assert) {
        await visit("/t/this-is-a-test-topic/9");
        await click(".topic-post[data-post-number='1'] button.reply");

        assert
          .dom("#reply-control.open")
          .exists("starts in open state by default");

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
        await visit("/t/this-is-a-test-topic/54081");
        await click(".topic-post[data-post-number='1'] button.reply");

        await selectKit(".composer-actions").expand();

        await selectKit(".composer-actions").selectRowByValue("toggle_whisper");

        assert
          .dom(".composer-actions svg.d-icon-far-eye-slash")
          .exists("sets the post type to whisper");

        await visit("/");
        assert
          .dom("#create-topic")
          .exists("the create topic button is visible");

        await click("#create-topic");
        assert
          .dom(".reply-details .whisper .d-icon-far-eye-slash")
          .doesNotExist("should reset the state of the composer's model");

        await selectKit(".composer-actions").expand();
        await selectKit(".composer-actions").selectRowByValue(
          "toggle_unlisted"
        );

        assert
          .dom(".reply-details .unlist")
          .includesText(i18n("composer.unlist"), "sets the topic to unlisted");

        await visit("/t/this-is-a-test-topic/9");

        await click(".topic-post[data-post-number='1'] button.reply");
        assert
          .dom(".reply-details .whisper")
          .doesNotExist("should reset the state of the composer's model");
      });

      test("Composer can toggle whisper when switching from reply to whisper to reply to topic", async function (assert) {
        await visit("/t/topic-with-whisper/960");

        await click(".topic-post[data-post-number='3'] button.reply");
        await click(".reply-details summary div");
        assert
          .dom('.reply-details li[data-value="toggle_whisper"]')
          .doesNotExist(
            "toggle whisper is not available when reply to whisper"
          );
        await click('.reply-details li[data-value="reply_to_topic"]');
        await click(".reply-details summary div");
        assert
          .dom('.reply-details li[data-value="toggle_whisper"]')
          .exists("toggle whisper is available when reply to topic");
      });

      test("Composer can toggle whisper when clicking reply to topic after reply to whisper", async function (assert) {
        await visit("/t/topic-with-whisper/54081");

        await click(".topic-post[data-post-number='3'] button.reply");
        await click("#reply-control .discard-button");
        await click(".timeline-footer-controls button.create");
        await click(".reply-details summary div");
        assert
          .dom('.reply-details li[data-value="toggle_whisper"]')
          .exists("toggle whisper is available when reply to topic");
      });

      test("Composer draft with dirty reply can toggle to edit", async function (assert) {
        await visit("/t/this-is-a-test-topic/9");

        await click(".topic-post[data-post-number='1'] button.reply");
        await fillIn(".d-editor-input", "This is a dirty reply");
        await click(".toggler");
        await click(".topic-post[data-post-number='2'] button.edit");
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

        await click(".topic-post[data-post-number='1'] button.reply");
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

      test("Does not check for existing draft", async function (assert) {
        await visit("/t/internationalization-localization/280");

        await click(
          ".topic-post[data-post-number='1'] button.show-more-actions"
        );
        await click(".topic-post[data-post-number='1'] button.edit");

        assert.dom(".dialog-body").doesNotExist("does not open the dialog");
        assert.dom(".d-editor-input").exists("the composer input is visible");
        assert.dom(".d-editor-input").hasValue(/^Any plans to support/);
      });

      test("Can switch states without abandon popup", async function (assert) {
        await visit("/t/internationalization-localization/280");

        const longText = "a".repeat(256);

        sinon.stub(Draft, "get").resolves({
          draft: null,
          draft_sequence: 0,
        });

        await click(".btn-primary.create.btn");

        await fillIn(".d-editor-input", longText);

        assert
          .dom(
            '.action-title a[href="/t/internationalization-localization/280"]'
          )
          .exists("the mode should be: reply to post");

        await click("article#post_3 button.reply");

        const composerActions = selectKit(".composer-actions");
        await composerActions.expand();
        await composerActions.selectRowByValue("reply_as_new_topic");

        assert
          .dom(".d-modal__body")
          .doesNotExist("abandon popup shouldn't come");

        assert
          .dom(".d-editor-input")
          .includesValue(longText, "entered text should still be there");

        assert
          .dom(
            '.action-title a[href="/t/internationalization-localization/280"]'
          )
          .doesNotExist("mode should have changed");
      });

      test("Does not replace recipient when another draft exists", async function (assert) {
        sinon.stub(Draft, "get").resolves({
          draft:
            '{"reply":"hello","action":"privateMessage","title":"hello","categoryId":null,"archetypeId":"private_message","metaData":null,"recipients":"codinghorror","composerTime":9159,"typingTime":2500}',
          draft_sequence: 0,
        });

        await visit("/u/charlie");
        await click("button.compose-pm");

        const privateMessageUsers = selectKit("#private-message-users");
        assert.strictEqual(privateMessageUsers.header().value(), "charlie");

        await click("#reply-control .discard-button");
        assert.dom(".d-editor-input").doesNotExist();
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

      test("modified placeholder with composer-editor-reply-placeholder is rendered", async function (assert) {
        withPluginApi((api) => {
          api.registerValueTransformer(
            "composer-editor-reply-placeholder",
            () => {
              return "modified_value";
            }
          );
        });

        await visit("/t/34");
        await click("article#post_3 button.reply");

        assert
          .dom(".d-editor-container textarea")
          .hasAttribute("placeholder", i18n("modified_value"));
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

        await fillIn(
          ".d-editor-input",
          "[quote][](https://github.com)[/quote]"
        );
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
        assert
          .dom(".composer-popup")
          .exists("shows the 'group_mentioned' notice");
      });

      test("Does not save invalid draft", async function (assert) {
        this.siteSettings.min_first_post_length = 20;

        await visit("/");
        await click("#create-topic");
        await fillIn("#reply-title", "Something");
        await fillIn(".d-editor-input", "Something");
        await click(".discard-button");
        assert.dom(".discard-draft-modal .save-draft").doesNotExist();
      });

      test("Saves drafts that only contain quotes", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click("#topic-footer-buttons .create");

        await fillIn(".d-editor-input", "[quote]some quote[/quote]");

        await click(".discard-button");
        assert.dom(".discard-draft-modal .save-draft").exists();
      });

      test("Discard drafts modal can be dismissed via keyboard", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click("#topic-footer-buttons .create");

        await fillIn(".d-editor-input", "[quote]some quote[/quote]");

        await click(".discard-button");
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
    }
  );

  acceptance(
    `Composer - Customizations (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
      });
      needs.user();
      needs.site({ can_tag_topics: true });

      function customComposerAction(composer) {
        return (
          (composer.tags || []).includes("monkey") &&
          composer.action === CREATE_TOPIC
        );
      }

      needs.hooks.beforeEach(() => {
        withPluginApi((api) => {
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
        assert
          .dom(".save-or-cancel button")
          .hasText(i18n("composer.create_topic"));
        const tags = selectKit(".mini-tag-chooser");
        await tags.expand();
        await tags.selectRowByValue("monkey");
        assert.dom(".action-title").hasText("custom text");
        assert.dom(".save-or-cancel button").hasText(i18n("composer.emoji"));
      });
    }
  );

  acceptance(
    `Composer - Error Extensibility (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
        general_category_id: 1,
        default_composer_category: 1,
      });

      needs.hooks.beforeEach(() => {
        withPluginApi((api) => {
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
        assert
          .dom(".dialog-body")
          .doesNotExist("does not pop up an error message");
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
    }
  );

  acceptance(
    `Composer - Focus Open and Closed (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
        allow_uncategorized_topics: true,
      });

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
        await composer.focusComposer({
          insertText: "this is some appended text",
        });

        await settled();
        assert.dom(".d-editor-input").isFocused("composer is open and focused");
        assert
          .dom("textarea.d-editor-input")
          .hasValue("this is some appended text");
      });

      test("Focusing a composer which is not open that has a draft", async function (assert) {
        await visit("/t/this-is-a-test-topic/9");

        await click(".topic-post[data-post-number='1'] button.edit");
        await fillIn(".d-editor-input", "This is a dirty reply");
        await click(".toggle-minimize");

        const composer = this.container.lookup("service:composer");
        await composer.focusComposer({
          insertText: "this is some appended text",
        });

        await settled();
        assert.dom(".d-editor-input").isFocused("composer is open and focused");
        assert
          .dom("textarea.d-editor-input")
          .hasValue("This is a dirty reply\n\nthis is some appended text");
      });
    }
  );

  // Default Composer Category tests
  acceptance(
    `Composer - Default category (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
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
        assert.strictEqual(
          selectKit(".category-chooser").header().value(),
          "2"
        );
        assert.strictEqual(
          selectKit(".category-chooser").header().name(),
          "test too"
        );
      });
    }
  );

  acceptance(
    `Composer - Uncategorized category (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
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
        assert.strictEqual(
          selectKit(".category-chooser").header().value(),
          null
        );
      });
    }
  );

  acceptance(
    `Composer - default category not set (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
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
        assert.strictEqual(
          selectKit(".category-chooser").header().value(),
          null
        );
        assert.strictEqual(
          selectKit(".category-chooser").header().name(),
          "category&hellip;"
        );
      });
    }
  );
  // END: Default Composer Category tests

  acceptance(
    `composer buttons API (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
        allow_uncategorized_topics: true,
      });
      needs.pretender((server, helper) => {
        server.get("/drafts/topic_280.json", function () {
          return helper.response(200, { draft: null });
        });
      });

      test("buttons can support a shortcut", async function (assert) {
        withPluginApi((api) => {
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

        const editor = find(".d-editor-input");
        editor.setSelectionRange(6, 9); // select the text input in the composer

        await triggerKeyEvent(".d-editor-input", "keydown", "B", {
          altKey: true,
          ...metaModifier,
        });

        assert
          .dom(".d-editor-input")
          .hasValue("hello **the** world", "adds the bold");

        await click(".toolbar-menu__options-trigger");

        const row = find("[data-name='bold']");
        assert
          .dom(row)
          .hasAttribute(
            "title",
            i18n("some_title") +
              ` (${translateModKey(PLATFORM_KEY_MODIFIER + " alt b")})`,
            "shows the title with shortcut"
          );
        assert
          .dom(row)
          .hasText(
            i18n("some_label") +
              ` ${translateModKey(PLATFORM_KEY_MODIFIER + " alt b")}`,
            "shows the label with shortcut"
          );
      });

      test("buttons with shortcuts can have their shortcut in title conditionally hidden", async function (assert) {
        withPluginApi((api) => {
          api.onToolbarCreate((toolbar) => {
            toolbar.addButton({
              id: "smile",
              group: "extras",
              name: "smile",
              icon: "far-face-smile",
              title: "cheese",
              shortcut: "ALT+S",
              hideShortcutInTitle: true,
            });
          });
        });

        await visit("/t/internationalization-localization/280");
        await click(".post-controls button.reply");
        await fillIn(".d-editor-input", "hello the world");

        assert
          .dom(".d-editor-button-bar .smile")
          .hasAttribute(
            "title",
            i18n("cheese"),
            "shows the title without the shortcut"
          );
      });

      test("buttons can support a shortcut that triggers a custom action", async function (assert) {
        withPluginApi((api) => {
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

        const editor = find(".d-editor-input");
        await triggerKeyEvent(".d-editor-input", "keydown", "S", {
          altKey: true,
          ...metaModifier,
        });

        assert.dom(editor).hasValue(":smile: from keyboard");
      });

      test("buttons with conditions should not trigger shortcut actions when condition is false", async function (assert) {
        withPluginApi((api) => {
          api.onToolbarCreate((toolbar) => {
            toolbar.addButton({
              id: "smile",
              group: "extras",
              icon: "far-face-smile",
              shortcut: "ALT+S",
              shortcutAction: (toolbarEvent) => {
                toolbarEvent.addText(":smile: from keyboard");
              },
              condition: () => false,
            });
          });
        });

        await visit("/t/internationalization-localization/280");
        await click(".post-controls button.reply");

        const editor = find(".d-editor-input");
        await triggerKeyEvent(".d-editor-input", "keydown", "S", {
          altKey: true,
          ...metaModifier,
        });

        assert.dom(editor).hasValue("");
      });

      test("buttons with conditions should trigger shortcut actions when condition is true", async function (assert) {
        withPluginApi((api) => {
          api.onToolbarCreate((toolbar) => {
            toolbar.addButton({
              id: "smile",
              group: "extras",
              icon: "far-face-smile",
              shortcut: "ALT+S",
              shortcutAction: (toolbarEvent) => {
                toolbarEvent.addText(":smile: from keyboard");
              },
              condition: () => true,
            });
          });
        });

        await visit("/t/internationalization-localization/280");
        await click(".post-controls button.reply");

        const editor = find(".d-editor-input");
        await triggerKeyEvent(".d-editor-input", "keydown", "S", {
          altKey: true,
          ...metaModifier,
        });

        assert.dom(editor).hasValue(":smile: from keyboard");
      });

      test("buttons can be added conditionally", async function (assert) {
        withPluginApi((api) => {
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
        await click(".toolbar-menu__options-trigger");

        assert
          .dom(`button[title="${expectedName}"]`)
          .doesNotExist("custom button is not displayed for reply");

        await click(".toolbar-menu__options-trigger");

        await visit("/latest");
        await click("#create-topic");

        await click(".toolbar-menu__options-trigger");

        assert
          .dom(`button[title="${expectedName}"]`)
          .exists("custom button is displayed for new topic");
      });

      test("modified name when replying to a post", async function (assert) {
        withPluginApi((api) => {
          api.registerValueTransformer(
            "composer-reply-options-user-link-name",
            () => {
              return "NewNameHere";
            }
          );
        });

        await visit("/t/34");
        await click("article#post_3 button.reply");

        assert.dom(".reply-details .user-link").hasText("NewNameHere");
      });

      test("modified avatar when replying to a post", async function (assert) {
        withPluginApi((api) => {
          api.registerValueTransformer(
            "composer-reply-options-user-avatar-template",
            () => {
              return "/images/avatar.png?size={size}";
            }
          );
        });

        await visit("/t/34");
        await click("article#post_3 button.reply");

        assert
          .dom(".reply-details .action-title img")
          .hasAttribute(
            "src",
            /\/images\/avatar\.png/,
            "Reply avatar can be customized"
          );
      });

      test("modified avatar in quote", async function (assert) {
        withPluginApi((api) => {
          api.registerValueTransformer(
            "composer-editor-quoted-post-avatar-template",
            () => {
              return "/images/custom-quote-avatar.png?size={size}";
            }
          );
        });

        await visit("/t/34");
        await click("article#post_3 button.reply");
        await fillIn(
          ".d-editor-input",
          '[quote="charlie, post:1, topic:34"]\noriginal post content\n[/quote]'
        );

        assert
          .dom(".d-editor-preview .quote .title img")
          .hasAttribute(
            "src",
            /\/images\/custom-quote-avatar\.png/,
            "Quote avatar can be customized"
          );
      });
    }
  );
});
