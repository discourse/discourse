import { click, fillIn, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import Draft from "discourse/models/draft";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import topicFixtures from "discourse/tests/fixtures/topic";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  selectText,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function composerActionsDropdown() {
  return {
    async expand() {
      await click(".composer-actions-trigger");
    },
    async selectRowByValue(value) {
      await click(`[data-action-id='${value}']`);
    },
    rows() {
      return document.querySelectorAll(
        ".composer-actions-dropdown [data-action-id]"
      );
    },
    actionIds() {
      return [...this.rows()].map((row) => row.dataset.actionId);
    },
  };
}

acceptance(`Composer Actions (new composer actions)`, function (needs) {
  needs.user({
    id: 5,
    username: "kris",
    whisperer: true,
  });
  needs.settings({
    prioritize_username_in_ux: true,
    display_name_on_posts: false,
    enable_new_composer_actions: true,
  });
  needs.site({ can_tag_topics: true });
  needs.pretender((server, helper) => {
    server.put("/u/kris.json", () => helper.response({ user: {} }));
    const cardResponse = cloneJSON(userFixtures["/u/shade/card.json"]);
    server.get("/u/shade/card.json", () => helper.response(cardResponse));
    server.get("/c/shared-drafts/24/l/latest.json", () => {
      const response = cloneJSON(discoveryFixtures["/c/bug/1/l/latest.json"]);
      response.topic_list.can_create_topic = true;
      response.topic_list.filter = "c/shared-drafts/24/l/latest";

      return helper.response(response);
    });
    server.get("/t/54077.json", () => {
      const response = cloneJSON(topicFixtures["/t/54077.json"]);
      response.fancy_title =
        '<span dir="auto">Short topic with two posts</span>';

      return helper.response(response);
    });
  });

  test("replying to post", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");
    await composerActions.expand();

    assert.deepEqual(composerActions.actionIds().sort(), [
      "reply_as_new_topic",
      "reply_to_topic",
    ]);
  });

  test("replying to post - reply_to_topic", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");
    await fillIn(
      ".d-editor-input",
      "test replying to topic when initially replied to post"
    );

    await composerActions.expand();
    await composerActions.selectRowByValue("reply_to_topic");

    assert
      .dom(".composer-actions-trigger")
      .includesText(i18n("composer.composer_actions.reply_to_topic.trigger"));
    assert
      .dom(".d-editor-input")
      .hasValue("test replying to topic when initially replied to post");
  });

  test("toggle whisper via actions dropdown for whisperers", async function (assert) {
    updateCurrentUser({ admin: false, moderator: false });

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    await click(".composer-actions-trigger");

    assert
      .dom(".composer-toggle-whisper")
      .exists("whisper toggle item is visible in dropdown");

    await click(".composer-toggle-whisper .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-whisper .d-toggle-switch__checkbox[aria-checked='true']"
      )
      .exists("whisper toggle is on after click");

    await click(".composer-toggle-whisper .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-whisper .d-toggle-switch__checkbox[aria-checked='false']"
      )
      .exists("whisper toggle is off after second click");
  });

  test("replying to post - reply_as_new_topic", async function (assert) {
    sinon.stub(Draft, "get").resolves({ draft: "", draft_sequence: 0 });

    const composerActions = composerActionsDropdown();
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

    assert.strictEqual(categoryChooserReplyArea.header().name(), "faq");
    assert.dom(".d-editor-input").includesValue(quote);
  });

  test("reply_as_new_topic without a new_topic draft", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".create.reply");
    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_new_topic");
    assert.dom(".dialog-body").doesNotExist();
  });

  test("reply_as_new_group_message", async function (assert) {
    await visit("/t/lorem-ipsum-dolor-sit-amet/130");
    await click(".create.reply");
    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_new_group_message");

    const privateMessageUsers = selectKit("#private-message-users");
    assert.deepEqual(privateMessageUsers.header().value(), "foo,foo_group");
  });

  test("reply_as_new_topic without a permission to create topic", async function (assert) {
    updateCurrentUser({ can_create_topic: false });
    await visit("/t/internationalization-localization/280");
    await click(".create.reply");
    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    assert
      .dom(".composer-actions-dropdown [data-action-id='reply_as_new_topic']")
      .doesNotExist("reply as new topic option is not visible");
  });

  test("interactions", async function (assert) {
    const composerActions = composerActionsDropdown();
    const quote = "Life is like riding a bicycle.";

    await visit("/t/short-topic-with-two-posts/54077");
    await click("article#post_2 button.reply");
    await fillIn(".d-editor-input", quote);
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_to_topic");

    assert
      .dom(".composer-actions-trigger")
      .includesText(i18n("composer.composer_actions.reply_to_topic.trigger"));
    assert.dom(".d-editor-input").hasValue(quote);

    await composerActions.expand();

    assert.deepEqual(composerActions.actionIds().sort(), [
      "reply_as_new_topic",
      "reply_to_post",
    ]);

    await composerActions.selectRowByValue("reply_to_post");
    await composerActions.expand();

    assert.dom(".composer-actions-trigger").includesText("tms");
    assert.dom(".d-editor-input").hasValue(quote);
    assert.deepEqual(composerActions.actionIds().sort(), [
      "reply_as_new_topic",
      "reply_to_topic",
    ]);

    await composerActions.selectRowByValue("reply_as_new_topic");
    await composerActions.expand();

    assert.dom(".d-editor-input").includesValue(quote);
    assert.deepEqual(composerActions.actionIds().sort(), [
      "create_private_message",
      "reply_to_post",
      "reply_to_topic",
      "shared_draft",
    ]);
  });

  test("interactions - private message", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click('#post_4 a[data-user-card="shade"]');
    await click(".usercard-controls .compose-pm .btn-primary");
    await composerActions.expand();

    assert.deepEqual(composerActions.actionIds().sort(), ["create_topic"]);
  });

  test("reply target link uses plain topic title when fancy title includes HTML", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54077");
    await click(".create.reply");

    await visit("/");
    await waitFor(".composer-actions-reply-target-link__label");

    assert
      .dom(".composer-actions-reply-target-link__label")
      .hasText(
        "Short topic with two posts",
        "renders the plain topic title in the reply target link"
      );
  });

  test("toggle no-bump via actions dropdown", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54077");
    await click("article#post_2 button.reply");

    await click(".composer-actions-trigger");

    assert
      .dom(".composer-toggle-no-bump")
      .exists("no-bump toggle item is visible in dropdown");

    await click(".composer-toggle-no-bump .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-no-bump .d-toggle-switch__checkbox[aria-checked='true']"
      )
      .exists("no-bump toggle is on after click");

    await click(".composer-toggle-no-bump .d-toggle-switch__checkbox");

    assert
      .dom(
        ".composer-toggle-no-bump .d-toggle-switch__checkbox[aria-checked='false']"
      )
      .exists("no-bump toggle is off after second click");
  });

  test("replying to post as staff shows whisper + no-bump toggles in dropdown", async function (assert) {
    updateCurrentUser({ admin: true });
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    await click(".composer-actions-trigger");

    assert
      .dom(".composer-toggle-whisper")
      .exists("whisper toggle is visible for staff");
    assert
      .dom(".composer-toggle-no-bump")
      .exists("no-bump toggle is visible for staff");
  });

  test("replying to post as TL3 user shows no toggles in dropdown", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 3,
      whisperer: false,
      groups: [{ id: 13, name: "tl3_group" }],
    });
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    await click(".composer-actions-trigger");

    assert
      .dom(".composer-toggle-whisper")
      .doesNotExist("whisper toggle is not visible for TL3 non-whisperer");
    assert
      .dom(".composer-toggle-no-bump")
      .doesNotExist("no-bump toggle is not visible for TL3 non-whisperer");
  });

  test("replying to post as TL4 user shows no-bump toggle in dropdown", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 4,
      whisperer: false,
      groups: [{ id: 13, name: "tl4_group" }],
    });
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    await click(".composer-actions-trigger");

    assert
      .dom(".composer-toggle-no-bump")
      .exists("no-bump toggle is visible for TL4");
  });

  test("editing post", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_1 button.show-more-actions");
    await click("article#post_1 button.edit");
    await composerActions.expand();

    assert.deepEqual(
      composerActions.actionIds(),
      [],
      "no switch actions are offered while editing a post"
    );
  });

  test("trigger shows correct icon for reply mode", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .exists("shows share icon when replying");
  });

  test("trigger shows correct icon for create topic mode", async function (assert) {
    await visit("/");
    await click("#create-topic");

    assert
      .dom(".composer-actions-trigger svg.d-icon-far-pen-to-square")
      .exists("shows pen-to-square icon when creating topic");
  });

  test("trigger shows correct icon for editing", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_1 button.show-more-actions");
    await click("article#post_1 button.edit");

    assert
      .dom(".composer-actions-trigger svg.d-icon-pencil")
      .exists("shows pencil icon when editing");
  });

  test("trigger shows correct label for reply mode", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert
      .dom(".composer-actions-trigger")
      .includesText("codinghorror", "shows reply to post label");
  });

  test("trigger shows the private message label when replying in a PM", async function (assert) {
    await visit("/t/lorem-ipsum-dolor-sit-amet/130");
    await click(".create.reply");

    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.composer_actions.reply_to_message.trigger"),
        "shows the private message reply label, not the topic label"
      );
  });

  test("trigger shows correct label for create topic mode", async function (assert) {
    await visit("/");
    await click("#create-topic");

    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.composer_actions.create_topic.label"),
        "shows create topic label"
      );
  });

  test("create topic mode shows correct actions and unlisted toggle", async function (assert) {
    const composer = this.owner.lookup("service:composer");
    const composerActions = composerActionsDropdown();
    updateCurrentUser({ admin: true });

    await visit("/");
    await click("#create-topic");
    await composerActions.expand();

    assert
      .dom(
        ".composer-actions-dropdown [data-action-id='create_private_message']"
      )
      .exists("shows create private message action");

    assert
      .dom(".composer-toggle-unlisted")
      .exists("unlisted toggle is visible for staff in create topic mode");

    await click(".composer-toggle-unlisted .d-toggle-switch__checkbox");
    composer.model.set("noBump", true);

    assert
      .dom(
        ".composer-toggle-unlisted .d-toggle-switch__checkbox[aria-checked='true']"
      )
      .exists("unlisted toggle is on after click");

    await composerActions.selectRowByValue("create_private_message");

    assert.false(
      composer.model.unlistTopic,
      "unlisted state is cleared when switching to a private message"
    );
    assert.false(
      composer.model.noBump,
      "no-bump state is cleared when switching to a private message"
    );

    await composerActions.expand();
    assert
      .dom(".composer-toggle-unlisted")
      .doesNotExist("unlisted toggle is not shown in private message mode");
  });

  test("create topic mode does not show reply_as_new_topic", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/");
    await click("#create-topic");
    await composerActions.expand();

    assert
      .dom(".composer-actions-dropdown [data-action-id='reply_as_new_topic']")
      .doesNotExist("does not show reply_as_new_topic in create topic mode");
  });
});

function stubDraftResponse() {
  sinon.stub(Draft, "get").resolves({
    draft:
      '{"reply":"dum de dum da ba.","action":"createTopic","title":"dum da ba dum dum","categoryId":null,"archetypeId":"regular","metaData":null,"composerTime":540879,"typingTime":3400}',
    draft_sequence: 0,
  });
}

acceptance(
  `Composer Actions With New Topic Draft (new composer actions)`,
  function (needs) {
    needs.user({ whisperer: true });

    needs.site({
      can_tag_topics: true,
    });

    needs.settings({
      enable_new_composer_actions: true,
    });

    test("shared draft", async function (assert) {
      updateCurrentUser({ draft_count: 1 });
      stubDraftResponse();

      await visit("/");
      await click("button.topic-drafts-menu-trigger");
      await waitFor(".topic-drafts-menu-content");
      await click(
        ".topic-drafts-menu-content .topic-drafts-item:first-child button"
      );

      await fillIn(
        "#reply-title",
        "This is the new text for the title using 'quotes'"
      );
      await fillIn(".d-editor-input", "This is the new text for the post");

      const tags = selectKit(".mini-tag-chooser");
      await tags.expand();
      await tags.selectRowByName("monkey");

      const composerActions = composerActionsDropdown();
      await composerActions.expand();
      await composerActions.selectRowByValue("shared_draft");

      assert.strictEqual(tags.header().name(), "monkey", "tags are not reset");
      assert
        .dom("#reply-title")
        .hasValue("This is the new text for the title using 'quotes'");

      assert
        .dom("#reply-control .btn-primary.create .d-button-label")
        .hasText(i18n("composer.create_shared_draft"));
      assert
        .dom(".composer-actions-trigger svg.d-icon-far-clipboard")
        .exists("shared draft icon is visible");

      await composerActions.expand();
      assert
        .dom(".composer-actions-dropdown [data-action-id='create_topic']")
        .exists("can switch back to create topic from shared draft mode");
      assert
        .dom(
          ".composer-actions-dropdown [data-action-id='create_private_message']"
        )
        .exists("can switch to PM from shared draft mode");
    });

    test("reply_as_new_topic with new_topic draft", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click(".create.reply");

      stubDraftResponse();

      const composerActions = composerActionsDropdown();
      await composerActions.expand();
      await composerActions.selectRowByValue("reply_as_new_topic");

      assert
        .dom(".dialog-body")
        .hasText(i18n("composer.composer_actions.reply_as_new_topic.confirm"));
      await click(".dialog-footer .btn-primary");

      assert.dom(".d-editor-input").hasValue(/^Continuing the discussion from/);
    });
  }
);

acceptance(`Prioritize Username (new composer actions)`, function (needs) {
  needs.user();
  needs.settings({
    prioritize_username_in_ux: true,
    display_name_on_posts: false,
    enable_new_composer_actions: true,
  });

  test("Reply to post use username", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await click("article#post_2 button.reply");

    assert.dom(".composer-actions-trigger").includesText("james_john");
  });

  test("Quotes use username", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await selectText("#post_2 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="james_john, post:2, topic:54079, full:true"]\nThis is a short topic.\n[/quote]\n\n'
      );
  });
});

acceptance(`Prioritize Full Name (new composer actions)`, function (needs) {
  needs.user();
  needs.settings({
    prioritize_username_in_ux: false,
    display_name_on_posts: true,
    enable_new_composer_actions: true,
  });

  test("Reply to post use full name", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await click("article#post_2 button.reply");

    assert
      .dom(".composer-actions-trigger")
      .includesText("james, john, the third");
  });

  test("Quotes use full name", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await selectText("#post_2 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="james, john, the third, post:2, topic:54079, full:true, username:james_john"]\nThis is a short topic.\n[/quote]\n\n'
      );
  });

  test("Quoting a nested quote returns the correct username", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await selectText("#post_4 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="james_john, post:2, topic:54079"]\nThis is a short topic.\n[/quote]\n\n'
      );
  });
});

acceptance(`Slow Mode (new composer actions)`, function (needs) {
  needs.user();
  needs.settings({ enable_new_composer_actions: true });
  needs.pretender((server, helper) => {
    server.get("/t/130.json", () => {
      const json = cloneJSON(topicFixtures["/t/130.json"]);
      // The 130 fixture is a PM; slow mode only applies to regular topics.
      json.archetype = "regular";
      json.slow_mode_seconds = 600;
      json.slow_mode_enabled_until = "2040-01-01T04:00:00.000Z";
      return helper.response(json);
    });
  });

  test("trigger shows the regular reply label with the slow-mode icon", async function (assert) {
    await visit("/t/internationalization-localization/130");
    await click("article#post_1 button.reply");

    assert
      .dom(".composer-actions-trigger svg.d-icon-hourglass-start")
      .exists("uses the slow-mode hourglass icon");
    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.composer_actions.reply_to_topic.trigger"),
        "falls back to the standard reply-to-topic trigger label"
      );
  });
});

acceptance(`Private Messages (new composer actions)`, function (needs) {
  needs.user();
  needs.settings({ enable_new_composer_actions: true });
  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => {
      const json = cloneJSON(topicFixtures["/t/280/1.json"]);
      json.archetype = "private_message";
      return helper.response(json);
    });
  });

  test("dropdown reply-to-thread item uses the private message label", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");
    await composerActions.expand();

    assert
      .dom(".composer-actions-dropdown [data-action-id='reply_to_topic']")
      .includesText(
        i18n("composer.composer_actions.reply_to_message.label"),
        "offers replying to the private message, not the topic"
      );
  });
});

acceptance(
  `Prioritizing Name fall back (new composer actions)`,
  function (needs) {
    needs.user();
    needs.settings({
      prioritize_username_in_ux: false,
      display_name_on_posts: true,
      enable_new_composer_actions: true,
    });

    test("Quotes fall back to username if name is not present", async function (assert) {
      await visit("/t/internationalization-localization/130");
      // select a user with no name
      await selectText("#post_1 p");
      await click(".insert-quote");
      assert
        .dom(".d-editor-input")
        .hasValue(
          '[quote="bianca, post:1, topic:130, full:true"]\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas a varius ipsum. Nunc euismod, metus non vulputate malesuada, ligula metus pharetra tortor, vel sodales arcu lacus sed mauris. Nam semper, orci vitae fringilla placerat, dui tellus convallis felis, ultricies laoreet sapien mi et metus. Mauris facilisis, mi fermentum rhoncus feugiat, dolor est vehicula leo, id porta leo ex non enim. In a ligula vel tellus commodo scelerisque non in ex. Pellentesque semper leo quam, nec varius est viverra eget. Donec vehicula sem et massa faucibus tempus.\n[/quote]\n\n'
        );
    });
  }
);
