import { click, fillIn, settled, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import { CREATE_TOPIC } from "discourse/models/composer";
import Draft from "discourse/models/draft";
import TopicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance(`Composer (new composer actions)`, function (needs) {
  needs.user({
    id: 5,
    username: "kris",
    whisperer: true,
  });
  needs.settings({
    general_category_id: 1,
    default_composer_category: 1,
    enable_new_composer_actions: true,
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
    ],
  });
  needs.pretender((server, helper) => {
    server.put("/u/kris.json", () => helper.response({ user: {} }));
    server.get("/t/960.json", () => {
      const topicList = cloneJSON(TopicFixtures["/t/9/1.json"]);
      topicList.post_stream.posts[2].post_type = 4;
      return helper.response(topicList);
    });
  });

  test("Replying to the first post in a topic is a topic reply", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#post_1 .reply.create");
    assert
      .dom(".composer-actions-trigger")
      .includesText(i18n("composer.composer_actions.reply_to_topic.trigger"));

    await click("#post_1 .reply.create");
    assert
      .dom(".composer-actions-trigger")
      .includesText(i18n("composer.composer_actions.reply_to_topic.trigger"));
  });

  test("Composer can toggle whispers when whisperer user", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click(".topic-post[data-post-number='1'] button.reply");

    await click(".composer-actions-trigger");

    assert
      .dom(".composer-toggle-whisper")
      .exists("whisper toggle item is visible in dropdown");

    await click(".composer-toggle-whisper .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-whisper .d-toggle-switch__checkbox[aria-checked='true']"
      )
      .exists("sets the post type to whisper");

    await click(".composer-toggle-whisper .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-whisper .d-toggle-switch__checkbox[aria-checked='false']"
      )
      .exists("removes the whisper mode");
  });

  module(
    "Composer can switch between new topic and new PM in different contexts",
    function () {
      test("within post/topic context", async function (assert) {
        const composer = this.owner.lookup("service:composer");

        await visit("/t/this-is-a-test-topic/54081");
        await click(".topic-post[data-post-number='1'] button.reply");
        await click(".composer-actions-trigger");
        assert
          .dom(
            ".composer-actions-dropdown [data-action-id='create_private_message']"
          )
          .doesNotExist("New message option is not present when in reply mode");
        await click(".composer-actions-trigger");

        await visit("/");
        await composer.openNewTopic();
        await settled();
        await click(".composer-actions-trigger");
        assert
          .dom(".composer-actions-dropdown [data-action-id='reply_to_topic']")
          .doesNotExist(
            "stale topic context is cleared when opening a fresh new-topic composer"
          );
        assert
          .dom(".composer-actions-dropdown [data-action-id='reply_to_post']")
          .doesNotExist(
            "stale post context is cleared when opening a fresh new-topic composer"
          );

        await click("[data-action-id='create_private_message']");
        assert
          .dom(".save-or-cancel button")
          .hasText(i18n("composer.create_pm"));

        await click(".composer-actions-trigger");
        await click("[data-action-id='create_topic']");
        assert
          .dom(".save-or-cancel button")
          .hasText(i18n("composer.create_topic"));
      });

      test("fresh new message clears stale reply context", async function (assert) {
        const composer = this.owner.lookup("service:composer");

        await visit("/t/this-is-a-test-topic/54081");
        await click(".topic-post[data-post-number='1'] button.reply");

        await visit("/");
        await composer.openNewMessage({ recipients: "shade" });
        await settled();

        await click(".composer-actions-trigger");
        assert
          .dom(".composer-actions-dropdown [data-action-id='reply_to_topic']")
          .doesNotExist(
            "stale topic context is cleared when opening a fresh message composer"
          );
        assert
          .dom(".composer-actions-dropdown [data-action-id='reply_to_post']")
          .doesNotExist(
            "stale post context is cleared when opening a fresh message composer"
          );
      });

      test("topic context is cleared after a successful save", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await click("article#post_3 button.reply");
        await fillIn(".d-editor-input", "this is a successful reply");
        await click("#reply-control button.create");

        await visit("/");
        await click("#create-topic");
        await click(".composer-actions-trigger");

        assert
          .dom(".composer-actions-dropdown [data-action-id='reply_to_topic']")
          .doesNotExist(
            "reply_to_topic is not surfaced after the previous composer was saved"
          );
        assert
          .dom(".composer-actions-dropdown [data-action-id='reply_to_post']")
          .doesNotExist(
            "reply_to_post is not surfaced after the previous composer was saved"
          );
      });
    }
  );

  test("Composer can toggle between reply and createTopic", async function (assert) {
    updateCurrentUser({ admin: true });
    await visit("/t/this-is-a-test-topic/54081");
    await click(".topic-post[data-post-number='1'] button.reply");

    await click(".composer-actions-trigger");
    await click(".composer-toggle-whisper .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-whisper .d-toggle-switch__checkbox[aria-checked='true']"
      )
      .exists("sets the post type to whisper");
    await click(".composer-actions-trigger");

    await visit("/");
    assert.dom("#create-topic").exists("the create topic button is visible");

    await click("#create-topic");
    assert
      .dom(".composer-whisper-indicator.--whispering")
      .doesNotExist("should reset the state of the composer's model");
    assert
      .dom(".save-or-cancel button .d-icon-far-eye-slash")
      .doesNotExist("the save button should not use the whisper icon");

    await click(".composer-actions-trigger");
    await click(".composer-toggle-unlisted .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-unlisted .d-toggle-switch__checkbox[aria-checked='true']"
      )
      .exists("sets the topic to unlisted");

    await visit("/t/this-is-a-test-topic/9");

    await click(".topic-post[data-post-number='1'] button.reply");
    assert
      .dom(".composer-whisper-indicator.--whispering")
      .doesNotExist("should reset the state of the composer's model");
    assert
      .dom(".composer-whisper-indicator.--public")
      .exists("the closed-state whisper indicator shows the reply is public");
  });

  test("Composer whisper toggle not shown when replying to whisper", async function (assert) {
    await visit("/t/topic-with-whisper/960");

    await click(".topic-post[data-post-number='3'] button.reply");
    await click(".composer-actions-trigger");
    assert
      .dom(".composer-toggle-whisper")
      .doesNotExist("whisper toggle is not available when reply to whisper");
    await click(".composer-actions-trigger");

    await click(".composer-actions-trigger");
    await click("[data-action-id='reply_to_topic']");

    await click(".composer-actions-trigger");
    assert
      .dom(".composer-toggle-whisper")
      .exists("whisper toggle is available when reply to topic");
  });

  test("Composer whisper toggle available when replying to topic after whisper", async function (assert) {
    await visit("/t/topic-with-whisper/54081");

    await click(".topic-post[data-post-number='3'] button.reply");
    await click("#reply-control .discard-button");
    await click(".timeline-footer-controls button.create");

    await click(".composer-actions-trigger");
    assert
      .dom(".composer-toggle-whisper")
      .exists("whisper toggle is available when reply to topic");
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
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.composer_actions.reply_to_topic.trigger"),
        "the mode should be: reply to topic"
      );

    await click("article#post_3 button.reply");

    await click(".composer-actions-trigger");
    await click("[data-action-id='reply_as_new_topic']");

    assert.dom(".d-modal__body").doesNotExist("abandon popup shouldn't come");

    assert
      .dom(".d-editor-input")
      .includesValue(longText, "entered text should still be there");

    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.composer_actions.create_topic.label"),
        "mode should have changed to create topic"
      );
  });
});

acceptance(
  `Composer - Customizations (new composer actions)`,
  function (needs) {
    needs.user();
    needs.site({ can_tag_topics: true });
    needs.settings({
      enable_new_composer_actions: true,
    });

    function customComposerAction(composer) {
      const tags = composer.tags || [];
      const hasMonkey = tags.some(
        (t) => (typeof t === "string" ? t : t.name) === "monkey"
      );
      return hasMonkey && composer.action === CREATE_TOPIC;
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
      assert
        .dom(".composer-actions-trigger")
        .includesText(
          i18n("composer.composer_actions.create_topic.label"),
          "trigger shows create topic label"
        );
      assert
        .dom(".save-or-cancel button")
        .hasText(i18n("composer.create_topic"));
      const tags = selectKit(".mini-tag-chooser");
      await tags.expand();
      await tags.selectRowByName("monkey");
      assert.dom(".composer-actions-trigger").includesText("custom text");
      assert.dom(".save-or-cancel button").hasText(i18n("composer.emoji"));
    });
  }
);
